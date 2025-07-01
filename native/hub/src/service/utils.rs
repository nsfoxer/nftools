use std::io::{Read, Write};
use crate::messages::common::{BoolMsg, DataMsg, StringMsg};
use crate::service::service::ImmService;
use std::ffi::OsStr;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::common::utils::{get_cache_dir, sha256};
use crate::messages::utils::{CompressLocalPicMsg, CompressLocalPicRspMsg, QrCodeDataMsg, QrCodeDataMsgList, SplitBackgroundImgMsg, SplitImageMsg};
use crate::{async_func_notype, async_func_typetype, func_end, func_typeno};
use anyhow::Result;
use futures_util::pending;
use image::{DynamicImage, ImageReader};
use log::info;
use opencv::core::{Mat, MatTrait, MatTraitConst, Point, Rect, Size, Vector};
use opencv::imgcodecs;
use opencv::imgproc::InterpolationFlags::INTER_LINEAR;
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
            StringMsg,
            split_background,
            SplitBackgroundImgMsg,
            split_img,
            ImageSplitMsg
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
    
    /// 分割背景图片
    async fn split_background(&self, msg: SplitBackgroundImgMsg) -> Result<StringMsg> {
        let handle = tokio::task::spawn_blocking(move || -> Result<StringMsg> {
            Self::split_background_img(msg)
        });
        handle.await?
    }

    /// 裁剪图片
    /// 返回裁剪后的图片地址
    async fn split_img(&self, msg: SplitImageMsg) -> Result<StringMsg> {
        tokio::task::spawn_blocking(move || -> Result<StringMsg> {
            Self::split_image(msg)
        }).await?
    }
}

impl UtilsService {

    /// 裁剪图片
    /// 返回裁剪后的图片地址
    fn split_image(msg: SplitImageMsg) -> Result<StringMsg> {
        let original_img = imgcodecs::imdecode(&Mat::from_slice(&Self::read_file(&msg.image)?)?, imgcodecs::IMREAD_COLOR)?;
        if original_img.empty() {
           return Err(anyhow::anyhow!("读取图片【{}】数据大小为空", msg.image));
        }

        if original_img.cols() < (msg.rect.left_x + msg.rect.width) as i32 || original_img.rows() < (msg.rect.left_y + msg.rect.height) as i32 {
            return Err(anyhow::anyhow!("图片裁剪区域超出图片范围"));
        }
        let rect = Rect::new(msg.rect.left_x as i32, msg.rect.left_y as i32, msg.rect.width as i32, msg.rect.height as i32);
        let cropped_image = original_img.roi(rect)?;

        let result_path = generate_path("png")?;
        let result_path = result_path.to_str().ok_or_else(|| anyhow::anyhow!("转换路径识别"))?;
        let mut buf = Vector::new();
        imgcodecs::imencode(".png", &cropped_image, &mut buf, &Vector::new())?;
        let mut file = std::fs::File::create(&result_path)?;
        file.write_all(buf.as_slice())?;

        Ok(StringMsg {
            value: result_path.to_string(),
        })
    }
    /// 下采样缩放比例
    const DOWN_SAMPLE_SCALE: i32 = 4;

    /// 分割背景图片
    /// return: 分割后的图片路径
    fn split_background_img(msg: SplitBackgroundImgMsg) -> Result<StringMsg> {
        // 1. 读取图片 img数据为BGR通道
        let original_img = imgcodecs::imdecode(&Mat::from_slice(&Self::read_file(&msg.src_img)?)?, imgcodecs::IMREAD_COLOR)?;
        if original_img.empty() {
           return Err(anyhow::anyhow!("读取图片【{}】数据大小为空", msg.src_img));
        }

        // 下采样
        let mut downsample = Mat::default();
        let (is_downsample, mut img) = if original_img.rows() > 1000 && original_img.cols() > 1000 {
            opencv::imgproc::resize(&original_img, &mut downsample, Size::new(original_img.cols()/Self::DOWN_SAMPLE_SCALE, original_img.rows()/Self::DOWN_SAMPLE_SCALE), 0.0, 0.0, INTER_LINEAR.into())?;
            (true, &downsample)
        } else {(false, &original_img)};

        // 2. 使用grab_cut进行分割
        // 创建掩码
        let mut mask: Mat = Mat::new_rows_cols_with_default(img.rows(), img.cols(), opencv::core::CV_8UC1, opencv::core::Scalar::from(0))?;
        // 定义矩形区域
        let rect = calculate_rect(msg.left_x, msg.left_y, msg.width, msg.height, img.cols(), img.rows());
        let mut bgd_model = Mat::new_rows_cols_with_default(1, 65, opencv::core::CV_64FC1, opencv::core::Scalar::from(0.0))?;
        let mut fgd_model = Mat::new_rows_cols_with_default(1, 65, opencv::core::CV_64FC1, opencv::core::Scalar::from(0.0))?;

        // 执行GrabCut分割 结果存在mask中 0:背景 1:前景 2:可能的前景 3:可能的背景
        opencv::imgproc::grab_cut(
            &img,
            &mut mask,
            rect,
            &mut bgd_model,
            &mut fgd_model,
            5,
            opencv::imgproc::GrabCutModes::GC_INIT_WITH_RECT.into(),
        )?;

        // 3. 将mask中0和2的像素值设置为0(透明)，1和3的像素值设置为255(不透明)
        let mut background_mask = Mat::default();
        // 比较mask中的值是否等于0.0，如果等于0.0，则将对应位置的值设置为255，否则设置为0.0
        opencv::core::compare(
            &mask,
            &opencv::core::Scalar::all(0.0),
            &mut background_mask,
            opencv::core::CmpTypes::CMP_EQ.into(),
        )?;
        // 比较mask中的值是否等于2.0，如果等于2.0，则将对应位置的值设置为255，否则设置为0.0
        let mut temp_mask = Mat::default();
        opencv::core::compare(
            &mask,
            &opencv::core::Scalar::all(2.0),
            &mut temp_mask,
            opencv::core::CmpTypes::CMP_EQ.into(),
        )?;
        // 背景掩码
        let mut background = Mat::default();
        // 合并 0.0和2.0的像素值为 背景
        opencv::core::bitwise_or(&background_mask, &temp_mask, &mut background, &Mat::default())?;
        let mut foreground = Mat::default();
        // 对背景取反获得前景
        opencv::core::bitwise_not(&background, &mut foreground, &Mat::default())?;
        // 将mask的背景为0(透明)，前景设置为255(不透明)
        mask.set_to(&opencv::core::Scalar::all(0.0), &background)?;
        mask.set_to(&opencv::core::Scalar::all(255.0), &foreground)?;

        // 如果是下采样，则需要恢复到原图大小
        if is_downsample {
            info!("下采样");
            let mut big_mask = Mat::default();
            opencv::imgproc::resize(&mask, &mut big_mask, Size::new(original_img.cols(), original_img.rows()), 0.0, 0.0, INTER_LINEAR.into())?;
            mask = big_mask;
            img = &original_img;
        }

        // 裁剪透明区域
        let (image, mask) = match trim_photo(img, &mask)? {
            Some(r)=>r,
            None => (img.clone().into(), mask.into()),
        };
        
        // 4. 将mask和img合并 得到新的图片
        let mut result = Mat::new_rows_cols_with_default(image.rows(), image.cols(), opencv::core::CV_8UC4 , opencv::core::Scalar::from(0))?;
        let mut reverse_mask = Mat::default();

        // 对mask取反
        opencv::core::bitwise_not(&mask, &mut reverse_mask, &Mat::default())?;
        for i in 0..3 {
            // 分别提取出BGR
            let mut tmp = Mat::default();
            opencv::core::extract_channel(&image, &mut tmp, i)?;
            // 再分别将BGR和mask合并，非掩码部分设置为0
            tmp.set_to(&opencv::core::Scalar::all(0.0), &reverse_mask)?;
            // 分别将BGR数据复制到result的BGR通道
            opencv::core::mix_channels(&tmp, &mut result, &[0, i])?;
        }
        // 设置透明通道
        opencv::core::mix_channels(&mask, &mut result, &[0, 3])?;
        let result_path = generate_path("png")?;
        let result_path = result_path.to_str().ok_or_else(|| anyhow::anyhow!("转换路径识别"))?;
        
        // 保存结果图片
        let mut buf = Vector::new();
        imgcodecs::imencode(".png", &result, &mut buf, &Vector::new())?;
        let mut file = std::fs::File::create(&result_path)?;
        file.write_all(buf.as_slice())?;

        Ok(StringMsg {
            value: result_path.to_string(),
        })
    }

    fn read_file(filename: &str) -> Result<Vec<u8>> {
        let mut file = std::fs::File::open(filename)?;
        let mut buf = Vec::new();
        file.read_to_end(&mut buf)?;
        Ok(buf)
    }
}

fn calculate_rect(left: f64, top: f64, width:f64, height:f64, img_width: i32, img_height: i32) -> opencv::core::Rect {
    let left = left * img_width as f64;
    let top = top * img_height as f64;
    let width = width * img_width as f64;
    let height = height * img_height as f64;
    opencv::core::Rect::new(left as i32, top as i32, width as i32, height as i32)
}

fn generate_path(suffix: &str) -> Result<PathBuf> {
    let mut path = get_cache_dir()?;
    let now = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)?;
    path.push(format!("{}.{}", now.as_millis(), suffix));    
    Ok(path)
}

///  裁剪透明区域
/// image: 原始图片
/// alpha_channel: 透明通道
pub fn trim_photo<'a>(image: &'a Mat, alpha_channel: &'a Mat) -> Result<Option<(opencv::boxed_ref::BoxedRef<'a, Mat>, opencv::boxed_ref::BoxedRef<'a, Mat>)>> {
    let bounding_rect = find_non_transparent_bbox(alpha_channel)?;
    let result = match bounding_rect { Some(rect) => {
        println!("original image box: {:?}", image);
        println!("original image box: {:?}", alpha_channel);
        println!("original bounding box: {:?}", rect);
        Some((image.roi(rect)?, alpha_channel.roi(rect)?))
    }, None => {None}};

    Ok(result)
}

fn find_non_transparent_bbox(alpha_channel: &Mat) -> Result<Option<opencv::core::Rect>> {
    let mut mask = Mat::default();
    opencv::imgproc::threshold(alpha_channel, &mut mask, 0.0, 255.0, opencv::imgproc::ThresholdTypes::THRESH_BINARY.into())?;

    let mut non_zero_points: Vector<Point> = Vector::new();
    opencv::core::find_non_zero(&mask, &mut non_zero_points)?;
    if non_zero_points.is_empty() {
        return Ok(None);
    }

    // 计算边界
    let mut min_x = i32::MAX;
    let mut min_y = i32::MAX;
    let mut max_x = i32::MIN;
    let mut max_y = i32::MIN;
    for point in non_zero_points.iter() {
        min_x = min_x.min(point.x);
        min_y = min_y.min(point.y);
        max_x = max_x.max(point.x);
        max_y = max_y.max(point.y);
    }
    let width = (max_x - min_x + 1).max(1);
    let height = (max_y - min_y +1).max(1);
    Ok(Some(opencv::core::Rect::new(min_x, min_y, width, height)))
}

#[allow(unused_imports)]
mod test {
    use std::fs::File;
    use std::io::Read;
    use std::time::SystemTime;
    use futures_util::{StreamExt, TryStreamExt};
    use image::open;
    use opencv::core::{MatTrait, Vector};
    use opencv::imgcodecs;
    use opencv::prelude::{Mat, MatTraitConst};
    use serde::Deserialize;
    use crate::messages::utils::{CompressLocalPicMsg, SplitBackgroundImgMsg};
    use crate::service::utils::{trim_photo, UtilsService};
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

    #[test]
    fn img2() {
        let req = SplitBackgroundImgMsg{
            src_img: r"/home/nsfoxer/图片/壁纸/【哲风壁纸】动画角色-尼克-朱迪.png".to_string(),
            left_x: 0.5,
            left_y: 0.5,
            width: 0.1,
            height: 0.1,
        };
        let r = UtilsService::split_background_img(req).unwrap();
        eprintln!("{:?}", r);
    }

    #[test]
    fn img() {
        // 1. 读取图片 img数据为BGR通道
        let img = opencv::imgcodecs::imread(r#"C:\Users\12618\Desktop\tmp\118.jpg"#, imgcodecs::IMREAD_COLOR).unwrap();
        if img.empty() {
            panic!("Could not read the image");
        }

        // 2. 使用grab_cut进行分割
        // 创建掩码
        let mut mask: Mat = Mat::new_rows_cols_with_default(img.rows(), img.cols(), opencv::core::CV_8UC1, opencv::core::Scalar::from(0)).unwrap();
        // 定义矩形区域
        let rect = opencv::core::Rect::new(25, 15, 408, 122);
        let mut bgd_model = Mat::new_rows_cols_with_default(1, 65, opencv::core::CV_64FC1, opencv::core::Scalar::from(0.0)).unwrap();
        let mut fgd_model = Mat::new_rows_cols_with_default(1, 65, opencv::core::CV_64FC1, opencv::core::Scalar::from(0.0)).unwrap();

        // 执行GrabCut分割 结果存在mask中 0:背景 1:前景 2:可能的前景 3:可能的背景
        opencv::imgproc::grab_cut(
            &img,
            &mut mask,
            rect,
            &mut bgd_model,
            &mut fgd_model,
            10,
            opencv::imgproc::GrabCutModes::GC_INIT_WITH_RECT.into(),
        ).unwrap();

        // 3. 将mask中0和2的像素值设置为0(透明)，1和3的像素值设置为255(不透明)
        let mut background_mask = Mat::default();
        // 比较mask中的值是否等于0.0，如果等于0.0，则将对应位置的值设置为255，否则设置为0.0
        opencv::core::compare(
            &mask,
            &opencv::core::Scalar::all(0.0),
            &mut background_mask,
            opencv::core::CmpTypes::CMP_EQ.into(),
        ).unwrap();
        // 比较mask中的值是否等于2.0，如果等于2.0，则将对应位置的值设置为255，否则设置为0.0
        let mut temp_mask = Mat::default();
        opencv::core::compare(
            &mask,
            &opencv::core::Scalar::all(2.0),
            &mut temp_mask,
            opencv::core::CmpTypes::CMP_EQ.into(),
        ).unwrap();
        // 背景掩码
        let mut background = Mat::default();
        // 合并 0.0和2.0的像素值为 背景
        opencv::core::bitwise_or(&background_mask, &temp_mask, &mut background, &Mat::default()).unwrap();
        let mut foreground = Mat::default();
        // 对背景取反获得前景
        opencv::core::bitwise_not(&background, &mut foreground, &Mat::default()).unwrap();
        // 将mask的背景为0(透明)，前景设置为255(不透明)
        mask.set_to(&opencv::core::Scalar::all(0.0), &background).unwrap();
        mask.set_to(&opencv::core::Scalar::all(255.0), &foreground).unwrap();

        // 4. 将mask和img合并 得到新的图片
        let mut result = Mat::new_rows_cols_with_default(img.rows(), img.cols(), opencv::core::CV_8UC4 , opencv::core::Scalar::from(0)).unwrap();
        let mut reverse_mask = Mat::default();

        // 对mask取反
        opencv::core::bitwise_not(&mask, &mut reverse_mask, &Mat::default()).unwrap();
        for i in 0..3 {
            // 分别提取出BGR
            let mut tmp = Mat::default();
            opencv::core::extract_channel(&img, &mut tmp, i).unwrap();
            // 再分别将BGR和mask合并，非掩码部分设置为0
            tmp.set_to(&opencv::core::Scalar::all(0.0), &reverse_mask).unwrap();
            // 分别将BGR数据复制到result的BGR通道
            opencv::core::mix_channels(&tmp, &mut result, &[0, i]).unwrap();
        }
        // 设置透明通道
        opencv::core::mix_channels(&mask, &mut result, &[0, 3]).unwrap();

        imgcodecs::imwrite(r"C:\Users\12618\Desktop\tmp\tmp.png", &result, &opencv::core::Vector::new()).unwrap();
    }

}
