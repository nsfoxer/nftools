use std::fs::create_dir_all;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};
use dirs::{cache_dir, config_dir};
use anyhow::{anyhow, Result};
use notify_rust::Timeout;
use sha2::{Digest, Sha256};

/// 工具类

/// 获取当前秒级时间戳
pub fn second_timestamp() -> u32  {
    SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap_or(Duration::from_secs(0)).as_secs() as u32
}

/// 获取数据缓存文件夹
/// 如果不存在，则会尝试创建
pub fn get_cache_dir() -> Result<PathBuf>  {
    let mut path = cache_dir().unwrap_or_default();
    path.push("nftools");
    if !path.exists() {
        create_dir_all(&path)?;
    }

    Ok(path)
}

/// 获取数据配置文件夹
/// 如果不存在，则会尝试创建
pub fn get_config_dir() -> Result<PathBuf>  {
    let mut path = config_dir().unwrap_or_default();
    path.push("nftools");
    if !path.exists() {
        create_dir_all(&path)?;
    }

    Ok(path)
}

/// 获取本机唯一id
pub fn get_machine_id() -> Result<String>  {
    Ok(machine_uid::machine_id::get_machine_id().or(Err(anyhow!("无法获取本机唯一id")))?)
}

/// 将数据转换为sha256小写hex
pub fn sha256(data: &[u8]) -> String {
    let mut sha256 = Sha256::new();
    sha256.update(data);
    format!("{:x}", sha256.finalize())
}

/// 获取当前用户名，没有则返回空
pub fn get_user_name() -> String {
    if cfg!(target_os = "windows") {
        std::env::var("USERNAME").unwrap_or_default()
    } else {
        std::env::var("USER").unwrap_or_default()
    }
}

/// 桌面通知
pub fn notify(body: &str) -> Result<()> {
    notify_rust::Notification::new()
        .summary(crate::common::APP_NAME)
        .icon(crate::common::APP_NAME)
        .timeout(Timeout::Milliseconds(2000))
        .body(body)
        .show()?;
    Ok(())
}
