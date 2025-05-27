use crate::messages::common::{BoolMsg, DataMsg, StringMsg};
use crate::service::service::ImmService;
use std::ffi::OsStr;
use std::path::PathBuf;
use std::time::UNIX_EPOCH;

use crate::common::utils::{get_cache_dir, sha256};
use crate::messages::utils::{CompressLocalPicMsg, CompressLocalPicRspMsg, QrCodeDataMsg, QrCodeDataMsgList};
use crate::{async_func_notype, async_func_typetype, func_end, func_typeno};
use anyhow::Result;
use image::{DynamicImage, ImageReader};
use qrcode_generator::QrCodeEcc;
use tokio::fs;
use tokio::fs::File;
use tokio::io::AsyncReadExt;

/// 工具类服务
pub struct UtilsService {}



#[async_trait::async_trait]
impl ImmService for UtilsService {

    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_typetype!(
            self,
            func,
            req_data,
            compress_local_img,
            CompressLocalPicMsg,
            gen_text_qr_code,
            StringMsg,
            gen_file_qr_code,
            StringMsg,
            detect_qr_code,
            DataMsg,
            detect_file_qr_code,
            StringMsg
        );
        async_func_notype!(self, func, network_status);
        func_typeno!(self, func, req_data, notify, StringMsg);
        func_end!(func)
    }
}

impl UtilsService {
    pub fn new() -> Self {
        Self {}
    }
}

impl UtilsService {
    /// 压缩图片
    /// local_img: 本地图片路径
    /// 返回： 压缩后的本地图片路径
    async fn compress_local_img(&self, local_img: CompressLocalPicMsg) -> Result<CompressLocalPicRspMsg> {
        // 1. 计算img的cache file
        let metadata = fs::metadata(&local_img.local_file).await?;
        let time = metadata.modified()?;
        let o_img = PathBuf::from(&local_img.local_file);
        let cache = sha256(
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
            // 读取图片宽高
            let img = cache_path.to_str().unwrap().to_string();
            let (width, height) = Self::get_img_size(&img)?;
            return Ok(CompressLocalPicRspMsg {
                local_file: img,
                width,
                height,
            });
        }

        // 3. 压缩
        let handle = tokio::task::spawn_blocking(move || -> Result<(PathBuf, u32, u32)> {
            let img = image::ImageReader::open(&local_img.local_file)?.with_guessed_format()?.decode()?;
            let cimg = img.resize(
                local_img.width,
                local_img.height,
                image::imageops::FilterType::Lanczos3,
            );
            cimg.save(&cache_path)?;
            Ok((cache_path, cimg.width(), cimg.height()))
        });
        let r = handle.await??;

        Ok(CompressLocalPicRspMsg {
            local_file: r.0.to_str().unwrap().to_string(),
            width: r.1,
            height: r.2,
        })
    }
    
    // 获取图片尺寸
    fn get_img_size(img: &str) -> Result<(u32, u32)> {
        // 1. 打开图片
        let img = ImageReader::open(img)?.with_guessed_format()?.decode()?;
        
        // 2. 获取图片尺寸
        Ok((img.width(), img.height()))
    }

    /// 桌面通知
    fn notify(&self, body: StringMsg) -> Result<()> {
        crate::common::utils::notify(body.value.as_str())
    }

    /// 检查网络状态
    async fn network_status(&self) -> Result<BoolMsg> {
        let client = reqwest::Client::new();
        let response = client.get("https://www.baidu.com").send().await;
        
        Ok(BoolMsg{
            value: response.is_ok(),
        })
    }

    // 对字符串生成二维码
    async fn gen_text_qr_code(&self, msg: StringMsg) -> Result<DataMsg> {
        // 如果数据长度超出二维码最大容量，则返回错误
        if msg.value.as_bytes().len() > 2953 {
            return Err(anyhow::anyhow!("数据长度超出二维码最大容量"));
        }
        let handle = tokio::task::spawn_blocking(move || -> Result<Vec<u8>> {
            Ok(qrcode_generator::to_png_to_vec(msg.value, QrCodeEcc::Low, 1024)?)
        });
        let buf = handle.await??;
        Ok(DataMsg{value: buf})
    }
    // 对文件生成二维码
    async fn gen_file_qr_code(&self, msg: StringMsg) -> Result<DataMsg> {
        let mut file = File::open(&msg.value).await?;
        if file.metadata().await?.len() > 2953 {
            return Err(anyhow::anyhow!("数据长度超出二维码最大容量"));
        }
        // 读取文件所有字节
        let mut buffer = Vec::new();
        file.read_to_end(&mut buffer).await?;
        
        let handle = tokio::task::spawn_blocking(move || -> Result<Vec<u8>> {
           Ok(qrcode_generator::to_png_to_vec(buffer, QrCodeEcc::Low, 1024)?)
        });
        let buf = handle.await??;
        Ok(DataMsg{value: buf})
    }

    // 检测二维码(内存)
    async fn detect_qr_code(&self, msg: DataMsg) -> Result<QrCodeDataMsgList> {
        let img = image::load_from_memory(&msg.value)?;
        let handle = tokio::task::spawn_blocking(move || -> Result<QrCodeDataMsgList> {
            Self::detect_qr(img)
        });
        handle.await?
    }

    // 检测二维码(内存)
    async fn detect_file_qr_code(&self, msg: StringMsg) -> Result<QrCodeDataMsgList> {
        let handle = tokio::task::spawn_blocking(move || -> Result<QrCodeDataMsgList> {
            let img = image::open(&msg.value)?;
            Self::detect_qr(img)
        });
        handle.await?
    }
    
    // 检测二维码
    fn detect_qr(img: DynamicImage) -> Result<QrCodeDataMsgList> {
        let img_gray = img.into_luma8();
        let mut decoder = quircs::Quirc::default();
        let codes = decoder.identify(img_gray.width() as usize, img_gray.height() as usize, &img_gray);

        let mut result = Vec::new();
        for code in codes {
            let code = code?;
            let data = code.decode()?;
            result.push(QrCodeDataMsg {
                tl: (code.corners[0].x, code.corners[0].y),
                tr: (code.corners[1].x, code.corners[1].y),
                br: (code.corners[2].x, code.corners[2].y),
                bl: (code.corners[3].x, code.corners[3].y),
                data: data.payload,
            });
        }
        
        Ok(QrCodeDataMsgList{value: result, image_width: img_gray.width(), image_height: img_gray.height()})
    }
    
}

#[allow(unused_imports)]
mod test {
    use std::time::SystemTime;
    use futures_util::{StreamExt, TryStreamExt};
    use serde::Deserialize;
    use crate::messages::utils::CompressLocalPicMsg;
    use crate::service::utils::UtilsService;
    use tokio::time::Instant;

    #[tokio::test]
    async fn compress_local_img() {
        let service = UtilsService::new();
        let instant = Instant::now();
        let r = service
            .compress_local_img(CompressLocalPicMsg {
                local_file: "C:\\Users\\12618\\AppData\\Local\\Temp\\1748333211708.png"
                    .to_string(),
                width: 300,
                height: 200,
            })
            .await
            .unwrap();
        let r2 = instant.elapsed().as_millis();
        eprintln!("{:?} {r2}", r.local_file);
    }

}
