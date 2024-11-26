use crate::messages::common::StringMessage;
use crate::service::service::ImmService;
use std::ffi::OsStr;
use std::path::PathBuf;
use std::time::UNIX_EPOCH;

use crate::common::utils::{get_cache_dir, sha256};
use anyhow::Result;
use tokio::fs;
use crate::messages::utils::CompressLocalPicMsg;

/// 工具类服务
pub struct UtilsService {}

#[async_trait::async_trait]
impl ImmService for UtilsService {
    fn get_service_name(&self) -> &'static str {
        "Utils"
    }

    async fn handle(&self, func: &str, req_data: Vec<u8>) -> anyhow::Result<Option<Vec<u8>>> {
        todo!()
    }
}

impl UtilsService {
    fn new() -> Self {
        Self {}
    }
}

impl UtilsService {
    /// 压缩图片
    /// local_img: 本地图片路径
    /// 返回： 压缩后的本地图片路径
    async fn compress_local_img(&self, local_img: CompressLocalPicMsg) -> Result<StringMessage> {
        // 1. 计算img的cache file
        let metadata = fs::metadata(&local_img.local_file).await?;
        let time = metadata.modified()?;
        let o_img = PathBuf::from(&local_img.local_file);
        let mut cache = sha256(
            format!(
                "{}-{}-{}-{}",
                local_img.local_file,
                time.duration_since(UNIX_EPOCH)?.as_millis(),
                local_img.width,
                local_img.height
            )
            .as_bytes(),
        );
        let suffix = o_img
            .extension()
            .unwrap_or(OsStr::new("png"))
            .to_str()
            .unwrap_or("png");
        let mut cache_path = get_cache_dir()?;
        cache_path.push(cache + "." + suffix);

        // 2. 如果cache存在，则直接返回
        if cache_path.exists() {
            return Ok(StringMessage {
                value: cache_path.to_str().unwrap().to_string(),
            });
        }

        // 3. 压缩
        let handle = tokio::task::spawn_blocking(move || -> Result<PathBuf> {
            let img = image::open(local_img.local_file)?;
            let cimg = img.resize(local_img.width as u32, local_img.height as u32, image::imageops::FilterType::Lanczos3);
            cimg.save(&cache_path)?;
            Ok(cache_path)
        });
        let r = handle.await??;

        Ok(StringMessage{
            value: r.to_str().unwrap().to_string(),
        })
    }
}

mod test {
    use tokio::time::Instant;
    use crate::messages::utils::CompressLocalPicMsg;
    use crate::service::utils::UtilsService;

    #[tokio::test]
    async fn compress_local_img() {
        let service = UtilsService::new();
        let instant = Instant::now();
        let r = service.compress_local_img(CompressLocalPicMsg {
            local_file: r"C:\Users\12618\Pictures\wallpaper\wallhaven-p97klp_2560x1440.png".to_string(),
            width: 300,
            height: 200,
        }).await.unwrap();
        let r2 = instant.elapsed().as_millis();
        eprintln!("{:?} {r2}", r.value);
    }
}