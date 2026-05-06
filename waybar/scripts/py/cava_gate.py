#!/usr/bin/env python3
"""cava 门控：根据 PipeWire/Pulse 是否有播放流，对 cava 进程 STOP/CONT。

由 waybar_cava.sh fork：
    cava_gate.py --pid <cava_pid>

逻辑：
- 启动时检查一次 `pactl list short sink-inputs`：
    - 有流 → SIGCONT
    - 无流 → SIGSTOP
- `pactl subscribe` 监听 sink-input/sink 变化事件，每次事件去重检：
    - 有流 → 立即 SIGCONT，重置计时
    - 无流 → 启动 SILENCE_GRACE 秒倒计时，到点 SIGSTOP
- 检测 cava_pid 不存在 → 退出（waybar_cava.sh 重启 cava 时也会重 fork 本守护）。

依赖：pactl（pipewire-pulse 或 pulseaudio 均可）。
"""

from __future__ import annotations

import argparse
import os
import shutil
import signal
import subprocess
import sys
import threading
import time

SILENCE_GRACE = float(os.environ.get("WAYBAR_CAVA_SILENCE_GRACE", "5") or "5")
DEBUG = os.environ.get("WAYBAR_CAVA_GATE_DEBUG", "").strip() not in ("", "0", "false", "False")


def log(msg: str) -> None:
    if DEBUG:
        sys.stderr.write(f"[cava-gate {os.getpid()}] {msg}\n")
        sys.stderr.flush()


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def has_audio_streams() -> bool:
    """有任意"非 corked"的 sink-input → 有人在放音。

    `pactl list short sink-inputs` 包含暂停（corked）的流，必须用详细输出
    解析 `Corked: no` 才能区分"正在播"与"暂停"。
    """
    try:
        out = subprocess.check_output(
            ["pactl", "list", "sink-inputs"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0,
        )
    except Exception:
        return True  # 失败时保守按"播放中"，避免误 STOP
    in_block = False
    for line in out.splitlines():
        s = line.strip()
        if s.startswith("Sink Input #"):
            in_block = True
            continue
        if in_block and s.startswith("Corked:"):
            if s.split(":", 1)[1].strip().lower() == "no":
                return True
            in_block = False
    return False


class Gate:
    def __init__(self, cava_pid: int) -> None:
        self.cava_pid = cava_pid
        self.stopped = False
        self._lock = threading.Lock()
        self._silence_timer: threading.Timer | None = None

    def cont(self) -> None:
        with self._lock:
            if self._silence_timer is not None:
                self._silence_timer.cancel()
                self._silence_timer = None
            if not self.stopped:
                return
            try:
                os.kill(self.cava_pid, signal.SIGCONT)
                self.stopped = False
                log("CONT (audio detected)")
            except ProcessLookupError:
                pass

    def schedule_stop(self) -> None:
        with self._lock:
            if self.stopped:
                return
            if self._silence_timer is not None:
                return  # 已在等
            self._silence_timer = threading.Timer(SILENCE_GRACE, self._do_stop)
            self._silence_timer.daemon = True
            self._silence_timer.start()
            log(f"silence detected, will STOP in {SILENCE_GRACE}s")

    def _do_stop(self) -> None:
        with self._lock:
            self._silence_timer = None
            if self.stopped:
                return
            # 双重确认：定时器到点时再查一次，避免竞态
            if has_audio_streams():
                log("recheck: audio came back, abort STOP")
                return
            try:
                os.kill(self.cava_pid, signal.SIGSTOP)
                self.stopped = True
                log("STOP")
            except ProcessLookupError:
                pass

    def reevaluate(self) -> None:
        if has_audio_streams():
            self.cont()
        else:
            self.schedule_stop()


def watch_cava(gate: Gate) -> None:
    while pid_alive(gate.cava_pid):
        time.sleep(1.0)
    log("cava pid gone, exiting")
    # 确保退出时不留着 cava 在 STOP 状态
    if gate.stopped:
        try:
            os.kill(gate.cava_pid, signal.SIGCONT)
        except Exception:
            pass
    os._exit(0)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pid", type=int, required=True, help="cava 进程 PID")
    args = ap.parse_args()

    if not shutil.which("pactl"):
        log("pactl not found, exit (cava stays running)")
        return 0
    if not pid_alive(args.pid):
        return 0

    gate = Gate(args.pid)

    # 看门狗线程：cava 退出 → 守护退出
    threading.Thread(target=watch_cava, args=(gate,), daemon=True).start()

    # 初始评估
    gate.reevaluate()

    # 订阅 pactl 事件
    while pid_alive(args.pid):
        try:
            proc = subprocess.Popen(
                ["pactl", "subscribe"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except Exception as e:
            log(f"pactl subscribe failed: {e}")
            time.sleep(2.0)
            continue

        assert proc.stdout is not None
        for line in proc.stdout:
            if not pid_alive(args.pid):
                proc.terminate()
                return 0
            line = line.strip()
            # 关心 sink-input（最直接）和 sink（切换默认设备时）
            if "sink-input" in line or "sink" in line:
                gate.reevaluate()
        # 流断了（如 pipewire 重启），稍后重连
        log("pactl subscribe ended, reconnecting")
        time.sleep(1.0)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
