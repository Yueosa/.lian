#!/usr/bin/env bash
# 把默认 qs 配置指到 qsl（需能写 ~/.config/quickshell）
# 支持 sudo：用 SUDO_USER 的家目录，避免 HOME=/root
set -euo pipefail

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
    USER_HOME="${HOME}"
fi

TARGET="${USER_HOME}/.lian/qsl"
LINK="${USER_HOME}/.config/quickshell"

if [[ ! -f "${TARGET}/shell.qml" ]]; then
    echo "error: missing ${TARGET}/shell.qml" >&2
    exit 1
fi

ln -sfn "${TARGET}" "${LINK}"
echo "ok: $(ls -ld "${LINK}")"
echo "resolved: $(readlink -f "${LINK}")"
head -2 "${LINK}/shell.qml"
