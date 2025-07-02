use std::cmp::max;
use std::io::{Read, Write};
use std::sync::Arc;
use crate::service::service::Service;
use opencv::prelude::*;
use opencv::{core, imgcodecs, imgproc};
use crate::{async_func_nono, async_func_notype, async_func_typeno, async_func_typetype, func_end, func_nono, func_typeno};
use anyhow::Result;
use log::{debug, info};
use opencv::core::{compare, count_non_zero, mix_channels, AlgorithmHint, Point, Rect, Scalar, Size, ToInputArray, Vector};
use opencv::imgproc::ColorConversionCodes::COLOR_BGR2BGRA;
use opencv::imgproc::cvt_color;
use crate::common::utils::generate_path;
use crate::messages::common::StringMsg;
use crate::messages::image_split::{ColorMsg, ImageSplitReqMsg, MarkTypeMsg};
use tokio::sync::{Mutex, MutexGuard};

#[derive(Debug)]
pub struct ImageSplitService {
    original_path: String,
    handle_image: Arc<Mutex<Mat>>,
    bgd_model: Arc<Mutex<Mat>>,
    fgd_model: Arc<Mutex<Mat>>,
    mask: Arc<Mutex<Mat>>,
    scale: f64,
}

#[async_trait::async_trait]
impl Service for ImageSplitService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, create_image, StringMsg);
        func_nono!(self, func, clear);
        async_func_typetype!(self, func, req_data, handle_image, ImageSplitReqMsg);
        async_func_notype!(self, func, preview_image);

        func_end!(func)
    }
}

static THRESHOLD: i32 = 1000;
impl ImageSplitService {
    /// new
    pub fn new() -> Self {
        Self {
            original_path: String::with_capacity(0),
            handle_image: Arc::new(Mutex::new(Mat::default())),
            bgd_model: Arc::new(Mutex::new(Mat::default())),
            fgd_model: Arc::new(Mutex::new(Mat::default())),
            mask: Arc::new(Mutex::new(Mat::default())),
            scale: 1.0,
        }
    }

    /// 清除数据
    /// 降低内存使用
    fn clear(&mut self) -> Result<()>{
        self.handle_image = Arc::new(Mutex::new(Mat::default()));
        self.bgd_model = Arc::new(Mutex::new(Mat::default()));
        self.fgd_model = Arc::new(Mutex::new(Mat::default()));
        self.mask = Arc::new(Mutex::new(Mat::default()));
        Ok(())
    }
    

    /// 设置原始图片
    pub fn create_image(&mut self, img_path: StringMsg) -> Result<()> {
        let mut img = read_img(img_path.value.as_str())?;
        let max_size = img.rows().max(img.cols());
        
        // downsample
        let scale = if max_size > THRESHOLD * 4 {
            0.25
        } else if max_size > THRESHOLD {
            THRESHOLD as f64 / max_size as f64
        } else {
            1.0
        };
        let mut down_img = Mat::default();
        imgproc::resize(&img, &mut down_img, Size::new((img.cols() as f64 * scale) as i32, (img.rows() as f64 * scale) as i32),
                        0.0, 0.0, imgproc::INTER_LINEAR)?;
        img = down_img;
        
        let mask = Mat::new_rows_cols_with_default(img.rows(), img.cols(), core::CV_8UC1, Scalar::all(0.0))?;
        let bgd_model = Mat::new_rows_cols_with_default(1, 65, opencv::core::CV_64FC1, opencv::core::Scalar::from(0.0))?;
        let fgd_model = Mat::new_rows_cols_with_default(1, 65, opencv::core::CV_64FC1, opencv::core::Scalar::from(0.0))?;
        self.handle_image = Arc::new(Mutex::new(img));
        self.bgd_model = Arc::new(Mutex::new(bgd_model));
        self.fgd_model = Arc::new(Mutex::new(fgd_model));
        self.mask = Arc::new(Mutex::new(mask));
        self.scale = scale;
        self.original_path = img_path.value;

        Ok(())
    }

    /// 处理图片 中间过程
    async fn handle_image(&mut self, req: ImageSplitReqMsg) -> Result<StringMsg> {
        if self.handle_image.lock().await.empty() {
            return Err(anyhow::anyhow!("原始图片未设置"));
        }
        let original_image_arc = self.handle_image.clone();
        let bgd_model_arc = self.bgd_model.clone();
        let fgd_model_arc = self.fgd_model.clone();
        let mask_arc = self.mask.clone();

        tokio::task::spawn_blocking(move || {
            let original_image = futures::executor::block_on(original_image_arc.lock());
            let mut bgd_model = futures::executor::block_on(bgd_model_arc.lock());
            let mut fgd_model = futures::executor::block_on(fgd_model_arc.lock());
            let mut mask = futures::executor::block_on(mask_arc.lock());
            let value = match req.mark_type {
                MarkTypeMsg::Path => {Self::handle_path(&original_image, &mut bgd_model, &mut fgd_model, &mut mask, &req)?},
                MarkTypeMsg::Rect => {Self::handle_rect(&original_image, &mut bgd_model, &mut fgd_model, &mut mask, &req.mark_image, &req.add_color)?}
            };
            
            // 返回结果
            Ok(StringMsg {value})
        }).await?
    }

    async fn preview_image(&self) -> Result<StringMsg> {
        if self.handle_image.lock().await.empty() {
            return Err(anyhow::anyhow!("原始图片未设置"));
        }
        let mask_arc = self.mask.clone();
        let original_path = self.original_path.clone();
        let scale = self.scale;

        tokio::task::spawn_blocking(move || {
            let mask = futures::executor::block_on(mask_arc.lock());
            let value = Self::preview(&mask, original_path, scale)?;

            Ok(StringMsg{value})
        }).await?
    }

}

/// grabcut mask含义：
/// 0 - 背景
/// 1 - 前景
/// 2 - 可能的背景
/// 3 - 可能的前景
impl ImageSplitService {

    /// 处理矩形
    fn handle_rect(original_image: &Mat, bgd_model: &mut Mat, fgd_model: &mut Mat, mask: &mut Mat,
                   mark_image: &str, color: &ColorMsg) -> Result<String> {
        let mark_img = read_img(mark_image)?;
        // 1. 获取矩形边框
        let rect = Self::get_rect(original_image, &mark_img, color)?;

        // 2. 执行grabcut
        // mask中0和2的像素值为背景，1和3的像素为前景
        imgproc::grab_cut(original_image, mask, rect, bgd_model, fgd_model, 5, imgproc::GrabCutModes::GC_INIT_WITH_RECT.into())?;

        // 3. 将图片mask区域添加灰色蒙版
        let new_img = Self::gray_mask(original_image, mask)?;

        // 4. 保存图片
        Ok(write_img(&new_img)?)
    }

    /// 处理path
    fn handle_path(original_image: &Mat, bgd_model: &mut Mat, fgd_model: &mut Mat, mask: &mut Mat,
                   req: &ImageSplitReqMsg) -> Result<String> {
        let mut mark_img = read_img(&req.mark_image)?;
        // 1. 根据标记重新填充mask
        Self::change_mask(original_image, &mut mark_img, mask, req.add_color, req.del_color)?;

        // 2. 处理
        imgproc::grab_cut(original_image, mask, Rect::default(), bgd_model, fgd_model, 5, imgproc::GrabCutModes::GC_INIT_WITH_MASK.into())?;

        // 3. 将图片mask区域添加灰色蒙版
        let new_img = Self::gray_mask(original_image, mask)?;

        // 4. 保存图片
        Ok(write_img(&new_img)?)
    }

    /// 更新mask
    fn change_mask(original_image: &Mat, mark_img: &mut Mat, mask: &mut Mat, add_color: ColorMsg, del_color: ColorMsg) -> Result<()> {
        let resize = Size::new(original_image.cols(), original_image.rows());
        if let Some(add) = Self::extract_color_mask(mark_img, &add_color, resize.clone())? {
            info!("查找到新增区域");
            mask.set_to(&Scalar::all(1.0), &add)?;
        }
        if let Some(del) = Self::extract_color_mask(mark_img, &del_color, resize)? {
            info!("查找到删除区域");
            mask.set_to(&Scalar::all(0.0), &del)?;
        }
        Ok(())
    }
    // 辅助函数：提取特定颜色的掩码
    pub fn extract_color_mask(image: &Mat, color_msg: &ColorMsg, resize: Size) -> Result<Option<Mat>> {
        let lower = Scalar::new(
            ((color_msg.b as f64) - 10.0).max(0.0),
            ((color_msg.g as f64) - 10.0).max(0.0),
            ((color_msg.r as f64) - 10.0).max(0.0),
            0.0,
        );

        // 计算安全的颜色上限（最大为255）
        let upper = Scalar::new(
            ((color_msg.b as f64) + 10.0).min(255.0),
            ((color_msg.g as f64) + 10.0).min(255.0),
            ((color_msg.r as f64) + 10.0).min(255.0),
            0.0,
        );
        // 创建掩码
        let mut mask = Mat::default();
        core::in_range(image, &lower, &upper, &mut mask)?;
        if count_non_zero(&mask)? == 0 {
           return Ok(None);
        }
        // 调整大小
        let mut resized_mask = Mat::default();
        imgproc::resize(
            &mask,
            &mut resized_mask,
            resize,
            0.0,
            0.0,
            imgproc::INTER_NEAREST
        )?;
        Ok(Some(resized_mask))
    }

    /// 添加灰色遮罩
    fn gray_mask(img: &Mat, mask: &Mat) -> Result<Mat> {
        // 创建阴影遮罩矩阵 (例如半透明的灰色)
        let mut shadow_color = Mat::default();
        img.copy_to(&mut shadow_color)?;
        // 背景掩码 为2或0的像素被置位255
        let background = Self::get_background_from_mask(mask)?;
        shadow_color.set_to(&Scalar::new(191.0, 191.0, 191.0, 1.0), &background)?;
        // 混合图像
        let mut new_img = Mat::default();
        core::add_weighted(&img, 0.4, &shadow_color, 0.6, 0.0, &mut new_img, img.typ())?;

        Ok(new_img)
    }
    
    /// 获取矩形边框
    fn get_rect(img: &Mat, mark_img: &Mat, color: &ColorMsg) -> Result<Rect> {
        // 已知的RGB颜色 (替换为实际的RGB值)
        let (lower_color, upper_color) = color2hsv(color.r, color.g, color.b)?;

        // 转换为HSV颜色空间
        let mut hsv_img = Mat::default();
        
        cvt_color(&mark_img, &mut hsv_img, imgproc::COLOR_BGR2HSV, 0, AlgorithmHint::ALGO_HINT_DEFAULT)?;

        // 创建掩码，只保留目标颜色区域
        let mut mask = Mat::default();
        core::in_range(&hsv_img, &lower_color, &upper_color, &mut mask)?;

        // 查找轮廓
        let mut contours = Vector::<Vector<Point>>::new();
        imgproc::find_contours(
            &mask,
            &mut contours,
            imgproc::RETR_EXTERNAL,
            imgproc::CHAIN_APPROX_SIMPLE,
            Point::new(0, 0),
        )?;

        // 遍历轮廓并找到合适的矩形
        let mut rect = None;
        for contour in contours.iter() {
            let area = imgproc::contour_area(&contour, false)?;
            if area < 100.0 {
                continue;
            }
            // 多边形近似的精度参数，通常设置为轮廓周长的百分比
            let epsilon = 0.03 * imgproc::arc_length(&contour, true)?;
            let mut approx = Vector::<Point>::new();
            // 实现 Douglas-Peucker 算法，将曲线近似为多边形
            imgproc::approx_poly_dp(&contour, &mut approx, epsilon, true)?;
            if approx.len() != 4 {
                continue;
            }
            rect = Some(imgproc::bounding_rect(&approx)?);
        }

        // 矩形转换
        if let Some(rect) = rect {
            let o_width = img.cols() as f64;
            let width = mark_img.cols() as f64;
            let scale = o_width / width;
            let result = core::Rect::new(
                (rect.x as f64 * scale) as i32,
                (rect.y as f64 * scale) as i32,
                (rect.width as f64 * scale) as i32,
                (rect.height as f64 * scale) as i32,
            );
            Ok(result)
        } else {
            Err(anyhow::anyhow!("未找到符合条件的矩形边框"))
        }
    }

    /// 完成处理
    fn preview(mask: &Mat, original_path: String, scale: f64) -> Result<String> {
        let img = read_img(&original_path)?;
        let mut tmp_mask = Mat::default();
        let mask = if scale != 1.0 {
            imgproc::resize(&mask, &mut tmp_mask, Size::new(img.cols(), img.rows()), 0.0,0.0, imgproc::INTER_NEAREST)?;
            info!("up sample scale: {scale}");
            &tmp_mask
        } else {
            mask
        };
        
        let mut foreground = Mat::default();
        let background = Self::get_background_from_mask(&mask)?;
        core::bitwise_not(&background, &mut foreground, &Mat::default())?;
        //  将临时3通道图像转为4通道（添加默认Alpha=255）
        let mut tmp = Mat::default();
        core::bitwise_and(&img, &img, &mut tmp, &foreground)?;
        let mut result = Mat::default();
        cvt_color(&tmp, &mut result, COLOR_BGR2BGRA.into(), 0, AlgorithmHint::ALGO_HINT_DEFAULT)?;
        let mut alpha_channel = Mat::new_rows_cols_with_default(foreground.rows(), foreground.cols(), core::CV_8UC1, Scalar::all(0.0))?;
        alpha_channel.set_to(&Scalar::all(255.0), &foreground)?;
        mix_channels(&alpha_channel, &mut result, &[0, 3])?;

        let mut non_zero_points = Vector::<Point>::new();
        core::find_non_zero(&foreground, &mut non_zero_points)?;

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
        let rect = Rect::new(min_x, min_y, width, height);

        // 裁剪图像
        let cropped_img = result.roi(rect)?;
        Ok(write_img(&cropped_img)?)
    }

    fn get_background_from_mask(mask: &Mat) -> Result<Mat> {
        let mut temp_back1 = Mat::default();
        compare(&mask, &Scalar::all(0.0), &mut temp_back1, core::CmpTypes::CMP_EQ.into())?;
        let mut temp_back2 = Mat::default();
        compare(&mask, &Scalar::all(2.0), &mut temp_back2, core::CmpTypes::CMP_EQ.into())?;
        let mut background = Mat::default();
        core::bitwise_or(&temp_back1, &temp_back2, &mut background, &Mat::default())?;
        Ok(background)
    }
}


fn color2hsv(r: u8, g: u8, b: u8) -> Result<(Scalar, Scalar)> {
    // 转换为HSV
    let (hue, saturation, value) = rgb_to_hsv(r, g, b)?;
    let lower_hue = (hue - 10.0).max(0.0);
    let upper_hue = (hue + 10.0).min(180.0);
    let lower_saturation = (saturation - 30.0).max(50.0); // 提高下限以过滤灰色
    let upper_saturation = 255.0;
    let lower_value = (value - 50.0).max(50.0); // 提高下限以过滤黑色
    let upper_value = 255.0;
    let lower_color = Scalar::new(lower_hue, lower_saturation, lower_value, 0.0);
    let upper_color = Scalar::new(upper_hue, upper_saturation, upper_value, 0.0);

    Ok((lower_color, upper_color))
}

fn rgb_to_hsv(r: u8, g: u8, b: u8) -> Result<(f64, f64, f64)> {
    // 创建单像素RGB图像
    let mut rgb_img = Mat::new_rows_cols_with_default(1, 1, core::CV_8UC3, core::Scalar::all(0.0))?;
    let ptr = rgb_img.ptr_mut(0)?;
    unsafe {
        *ptr = b;       // Blue
        *(ptr.offset(1)) = g; // Green
        *(ptr.offset(2)) = r; // Red
    }

    // 转换为HSV
    let mut hsv_img = Mat::default();
    cvt_color(&rgb_img, &mut hsv_img, imgproc::COLOR_BGR2HSV, 0, AlgorithmHint::ALGO_HINT_DEFAULT)?;


    // 获取HSV值
    let hsv_ptr = hsv_img.ptr(0)?;
    let h = unsafe { *hsv_ptr } as f64;
    let s = unsafe { *hsv_ptr.offset(1) } as f64;
    let v = unsafe { *hsv_ptr.offset(2) } as f64;

    Ok((h, s, v))
}

pub fn read_img(filename: &str) -> Result<Mat> {
    let mut file = std::fs::File::open(filename)?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf)?;

    let original_img = imgcodecs::imdecode(&Mat::from_slice(&buf)?, imgcodecs::IMREAD_COLOR)?;
    if original_img.empty() {
        Err(anyhow::anyhow!("读取图片【{}】数据大小为空", filename))
    } else {
        Ok(original_img)
    }
}

fn write_img(img: &impl ToInputArray) -> Result<String> {
    let result_path = generate_path("png")?;
    let result_path = result_path.to_str().ok_or_else(|| anyhow::anyhow!("转换路径识别"))?;
    let mut buf = Vector::new();
    imgcodecs::imencode(".png", img, &mut buf, &Vector::new())?;
    let mut file = std::fs::File::create(&result_path)?;
    file.write_all(buf.as_slice())?;

    debug!("保存图片：{}",result_path);
    Ok(result_path.to_string())
}

mod test {
    use opencv::core::{MatTraitConst, Size};
    use crate::messages::common::StringMsg;
    use crate::messages::image_split::{ColorMsg, ImageSplitReqMsg, MarkTypeMsg};
    use crate::service::img::img_split::{read_img, write_img, ImageSplitService};

    #[tokio::test]
    async fn rect() {
        let mut img = ImageSplitService::new();
        img.create_image(StringMsg{value:r"C:\Users\12618\Desktop\1.png".to_string()}).unwrap();
        let req = ImageSplitReqMsg{
            mark_image: r"C:\Users\12618\Desktop\2.png".to_string(),
            mark_type: MarkTypeMsg::Rect,
            add_color: ColorMsg {
                r: 249,
                g: 100,
                b: 12,
                a: 1,
            },
            del_color: ColorMsg {
                r: 0,
                g: 0,
                b: 0,
                a: 0,
            },
        };
        let r = img.handle_image(req).await.unwrap();
        println!("结果： {}", r.value);
    }

    #[tokio::test]
    async fn path() {
        let mut img = ImageSplitService::new();
        img.create_image(StringMsg{value:r"C:\Users\12618\Desktop\1.jpg".to_string()}).unwrap();
        let req = ImageSplitReqMsg{
            mark_image: r"C:\Users\12618\Desktop\3.png".to_string(),
            mark_type: MarkTypeMsg::Rect,
            add_color: ColorMsg {
                r: 249,
                g: 100,
                b: 12,
                a: 1,
            },
            del_color: ColorMsg {
                r: 50,
                g: 49,
                b: 47,
                a: 255,
            },
        };
        let r = img.handle_image(req).await.unwrap();
        println!("<UNK> {}", r.value);

        let req = ImageSplitReqMsg{
            mark_image: r"C:\Users\12618\Desktop\2.png".to_string(),
            mark_type: MarkTypeMsg::Path,
            add_color: ColorMsg {
                r: 249,
                g: 100,
                b: 12,
                a: 1,
            },
            del_color: ColorMsg {
                r: 50,
                g: 49,
                b: 47,
                a: 255,
            },
        };
        let r = img.handle_image(req).await.unwrap();
        println!("<UNK> {}", r.value);
    }
    #[test]
    fn read() {
        let img = read_img(r"C:\Users\12618\Pictures\wallpaper\【哲风壁纸】CP-动物背影.png").unwrap();
        assert!(!img.empty());
        assert_eq!(img.channels(), 3);
    }
    
    #[test]
    fn extra_color() {
        let mask = ImageSplitService::extract_color_mask(&read_img(r"C:\Users\12618\Desktop\2.png").unwrap(), &ColorMsg {
            r: 50,
            g: 49,
            b: 48,
            a: 204,
        }, Size::new(567, 756)).unwrap();
        assert!(mask.is_some());
        write_img(&mask.unwrap()).unwrap();
    }

    #[tokio::test]
    async fn finish() {
        let mut img = ImageSplitService::new();
        img.create_image(StringMsg{value:r"C:\Users\12618\Desktop\1.jpg".to_string()}).unwrap();
        let req = ImageSplitReqMsg{
            mark_image: r"C:\Users\12618\Desktop\2.png".to_string(),
            mark_type: MarkTypeMsg::Rect,
            add_color: ColorMsg {
                r: 249,
                g: 100,
                b: 12,
                a: 1,
            },
            del_color: ColorMsg {
                r: 0,
                g: 0,
                b: 0,
                a: 0,
            },
        };
        let r = img.handle_image(req).await.unwrap();
        img.preview_image().await.unwrap();
    }

}