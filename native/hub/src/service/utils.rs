use std::io::Read;
use crate::messages::common::{BoolMsg, DataMsg, PairStringMsg, StringMsg};
use crate::service::service::ImmService;
use std::ffi::OsStr;
use std::path::PathBuf;
use std::time::UNIX_EPOCH;

use crate::common::utils::{get_cache_dir, sha256};
use crate::messages::utils::{CompressLocalPicMsg, CompressLocalPicRspMsg, QrCodeDataMsg, QrCodeDataMsgList, SplitImageMsg};
use crate::{async_func_notype, async_func_typeno, async_func_typetype, func_end, func_typeno};
use anyhow::Result;
use image::{DynamicImage, ImageReader};
use opencv::core::{Mat, MatTraitConst, Rect, Vector, VectorToVec};
use opencv::imgcodecs;
use qrcode_generator::QrCodeEcc;
use tokio::fs;
use tokio::fs::File;
use tokio::io::AsyncReadExt;
use crate::common::global_data::GlobalData;

/// 工具类服务
pub struct UtilsService {
    global_data: GlobalData,
}

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
            StringMsg,
            split_img,
            ImageSplitMsg,
            get_data,
            StringMsg
        );
        async_func_notype!(self, func, network_status);
        async_func_typeno!(self, func, req_data, set_data, PairStringMsg);
        func_typeno!(self, func, req_data, notify, StringMsg);
        func_end!(func)
    }
}

impl UtilsService {
    pub fn new(global_data: GlobalData) -> Self {
        Self {
            global_data
        }
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
        let mut img = rqrr::PreparedImage::prepare(img_gray);
        let grids = img.detect_grids();
        let mut result = Vec::new();
        for grid in grids {
            let mut buf = Vec::<u8>::new();
            let bounds = grid.bounds;
            if grid.decode_to(&mut buf).is_err() {
                continue;
            }
            result.push(QrCodeDataMsg {
                tl: (bounds[0].x, bounds[0].y),
                tr: (bounds[1].x, bounds[1].y),
                br: (bounds[2].x, bounds[2].y),
                bl: (bounds[3].x, bounds[3].y),
                data: buf,
            });
        }
        
        Ok(QrCodeDataMsgList{value: result, image_width: img.width() as u32, image_height: img.height() as u32})
    }

    /// 裁剪图片
    /// 返回裁剪后的图片地址
    async fn split_img(&self, msg: SplitImageMsg) -> Result<DataMsg> {
        tokio::task::spawn_blocking(move || {
            Self::split_image(msg)
        }).await?
    }
    
    const FRONTED_DATA: &'static str = "fronted_key:";
    
    /// 存储数据
    async fn set_data(&self, msg: PairStringMsg) -> Result<()> {
        self.global_data.set_data(format!("{}{}", Self::FRONTED_DATA,msg.key), &msg.value).await?;
        Ok(())
    }
    
    /// 设置数据
    async fn get_data(&self, msg: StringMsg) -> Result<StringMsg> {
        let key = format!("{}{}", Self::FRONTED_DATA,msg.value);
        let value: String = self.global_data.get_data(key).await.ok_or(anyhow::anyhow!("{}不存在", msg.value))?;
        Ok(StringMsg{value})
    }
    
}

impl UtilsService {

    /// 裁剪图片
    /// 返回裁剪后的图片地址
    fn split_image(msg: SplitImageMsg) -> Result<DataMsg> {
        let original_img = imgcodecs::imdecode(&Mat::from_slice(&msg.image.value)?, imgcodecs::IMREAD_COLOR)?;
        if original_img.empty() {
           return Err(anyhow::anyhow!("读取图片数据大小为空"));
        }

        if original_img.cols() < (msg.rect.left_x + msg.rect.width) as i32 || original_img.rows() < (msg.rect.left_y + msg.rect.height) as i32 {
            return Err(anyhow::anyhow!("图片裁剪区域超出图片范围"));
        }
        let rect = Rect::new(msg.rect.left_x as i32, msg.rect.left_y as i32, msg.rect.width as i32, msg.rect.height as i32);
        let cropped_image = original_img.roi(rect)?;

        let mut buf = Vector::new();
        imgcodecs::imencode(".png", &cropped_image, &mut buf, &Vector::new())?;

        Ok(DataMsg {
            value: buf.to_vec(),
        })
    }

    fn read_file(filename: &str) -> Result<Vec<u8>> {
        let mut file = std::fs::File::open(filename)?;
        let mut buf = Vec::new();
        file.read_to_end(&mut buf)?;
        Ok(buf)
    }
}