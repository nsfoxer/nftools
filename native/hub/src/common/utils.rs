use std::env;
use std::fs::create_dir_all;
use std::path::{Path, PathBuf};
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

/// 获取当前版本号
pub fn version() -> String {
    format!("v{}", env!("CARGO_PKG_VERSION"))
}

/// 获取当前执行程序的执行路径
pub fn location_path() -> Result<PathBuf> {
    Ok(env::current_exe()?)
}

/// 生成临时文件路径
pub fn generate_path(suffix: &str) -> Result<PathBuf> {
    let mut path = get_cache_dir()?;
    let now = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)?;
    path.push(format!("{}.{}", now.as_millis(), suffix));
    Ok(path)
}

/// 将索引转换为类似Excel列名的字符串（a, b, ..., z, aa, ab...）
pub fn index_to_string(index: usize) -> String {
    let mut n = index + 1; // 转换为1-based（1对应a，2对应b...）
    let mut bytes = Vec::new();

    while n > 0 {
        n -= 1; // 转为0-based偏移量（0对应a，25对应z）
        let remainder = n % 26; // 取余得到当前字符的偏移量（0-25）
        bytes.push(b'a' + remainder as u8); // 转换为字符的ASCII码（a的ASCII是97）
        n /= 26; // 处理更高位
    }

    bytes.reverse(); // 反转得到正确顺序
    String::from_utf8(bytes).unwrap() // 转换为字符串
}

/// path to file_name
pub fn path_to_file_name(path: &Path) -> Result<String> {
    Ok(path.file_name().ok_or_else(|| anyhow!("无法获取文件名"))?
        .to_str()
        .ok_or_else(|| anyhow!("无法将文件名转换为字符串"))?
        .to_string())
}
/// path to string
pub fn path_to_string(path: &Path) -> Result<String> {
    Ok(path
        .to_str()
        .ok_or_else(|| anyhow!("无法将文件名转换为字符串"))?
        .to_string())
}
