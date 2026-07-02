// 温度传感器 — 读 /sys/class/hwmon
use crate::model::Thermal;
use std::fs;

pub fn sample() -> Thermal {
    let mut cpu_package = 0f64;
    let mut cpu_hottest = 0f64;
    let mut ssd = 0f64;
    let mut wifi = 0f64;

    for i in 0.. {
        let base = format!("/sys/class/hwmon/hwmon{}", i);
        let name_path = format!("{}/name", base);
        let Ok(name) = fs::read_to_string(&name_path) else { break };
        let name = name.trim();

        match name {
            "coretemp" => {
                for t in read_all_temp_inputs(&base) {
                    if t > cpu_hottest { cpu_hottest = t; }
                }
                cpu_package = read_temp(&base, "temp1_input"); // Package id 0
            }
            "acpitz" => {
                // 整机温度，如果没有 coretemp 就作为 fallback
                let t = read_temp(&base, "temp1_input");
                if cpu_package == 0.0 { cpu_package = t; }
                if t > cpu_hottest { cpu_hottest = t; }
            }
            "nvme" => {
                ssd = read_temp(&base, "temp1_input");
            }
            "iwlwifi_1" => {
                wifi = read_temp(&base, "temp1_input");
            }
            _ => {}
        }
    }

    Thermal { cpu_package, cpu_hottest_core: cpu_hottest, ssd, wifi }
}

fn read_temp(base: &str, file: &str) -> f64 {
    let path = format!("{}/{}", base, file);
    let Ok(s) = fs::read_to_string(&path) else { return 0.0 };
    s.trim().parse::<f64>().unwrap_or(0.0) / 1000.0
}

fn read_all_temp_inputs(base: &str) -> Vec<f64> {
    let mut values = vec![];
    for i in 1..=30 {
        let name = format!("temp{}_input", i);
        let path = format!("{}/{}", base, name);
        let Ok(s) = fs::read_to_string(&path) else { continue };
        if let Ok(v) = s.trim().parse::<f64>() {
            values.push(v / 1000.0);
        }
    }
    values
}
