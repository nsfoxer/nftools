use std::fs::create_dir_all;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};
use dirs::{config_local_dir, data_local_dir};
use anyhow::{anyhow, Result};

/// 工具类

/// 获取当前秒级时间戳
pub fn second_timestamp() -> u32  {
    SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap_or(Duration::from_secs(0)).as_secs() as u32
}

/// 获取数据缓存文件夹
/// 如果不存在，则会尝试创建
pub fn get_data_dir() -> Result<PathBuf>  {
    let mut path = data_local_dir().unwrap_or_default();
    path.push("nftools");
    if !path.exists() {
        create_dir_all(&path)?;
    }

    Ok(path)
}

/// 获取数据配置文件夹
/// 如果不存在，则会尝试创建
pub fn get_config_dir() -> Result<PathBuf>  {
    let mut path = config_local_dir().unwrap_or_default();
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