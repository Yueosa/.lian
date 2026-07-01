// HTTP 客户端 — GET/POST JSON，统一超时和 UA
use serde_json::Value;
use std::time::Duration;

const TIMEOUT: Duration = Duration::from_secs(3);

pub fn get_json(url: &str, referer: &str) -> Result<Value, String> {
    let agent = ureq::Agent::new_with_config(
        ureq::Agent::config_builder().timeout_global(Some(TIMEOUT)).build()
    );
    let mut resp = agent.get(url)
        .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
        .header("Referer", referer)
        .call()
        .map_err(|e| format!("请求失败: {}", e))?;
    let body = resp.body_mut().read_to_string().map_err(|e| format!("读取失败: {}", e))?;
    serde_json::from_str(&body).map_err(|e| format!("JSON: {}", e))
}

pub fn post_json(url: &str, body: &str, referer: &str) -> Result<Value, String> {
    let agent = ureq::Agent::new_with_config(
        ureq::Agent::config_builder().timeout_global(Some(TIMEOUT)).build()
    );
    let mut resp = agent.post(url)
        .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
        .header("Referer", referer)
        .header("Content-Type", "application/x-www-form-urlencoded")
        .send(body.as_bytes())
        .map_err(|e| format!("请求失败: {}", e))?;
    let body_text = resp.body_mut().read_to_string().map_err(|e| format!("读取失败: {}", e))?;
    serde_json::from_str(&body_text).map_err(|e| format!("JSON: {}", e))
}
