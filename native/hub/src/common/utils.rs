use std::time::{Duration, SystemTime};

/// 工具类

/// 获取当前秒级时间戳
pub fn second_timestamp() -> u32  {
    SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap_or(Duration::from_secs(0)).as_secs() as u32
}