// HTTP 客户端 — 封装 ureq，统一错误处理
use crate::config;
use serde_json::Value;
use std::time::Duration;

/// GET 请求，返回 JSON 或错误消息
pub fn get_json(url: &str) -> Result<Value, String> {
    let agent = ureq::Agent::new_with_config(
        ureq::Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(config::HTTP_TIMEOUT)))
            .build()
    );

    let mut resp = agent.get(url)
        .header("User-Agent", config::USER_AGENT)
        .call()
        .map_err(|e| format!("HTTP 请求失败: {}", e))?;

    let body = resp.body_mut()
        .read_to_string()
        .map_err(|e| format!("读取响应失败: {}", e))?;

    serde_json::from_str(&body)
        .map_err(|e| format!("JSON 解析失败: {}", e))
}
