use image::DynamicImage;
use opencv::core::*;
use opencv::prelude::*;
use anyhow::Result;
use opencv::features2d;
use opencv::features2d::{BFMatcher, ORB};

pub struct OrbFeature {
    // 特征点集合，每个元素包含特征点的坐标、方向、尺度等信息
    // kp: Vector<KeyPoint>,
    kp_len: usize,
    // 描述子矩阵，每行对应一个特征点的 128 位二进制描述子
    desc: Mat
}


impl OrbFeature {

    /// 计算image的Orb特征点和描述子
    pub fn from(image: DynamicImage) -> Result<OrbFeature> {
        // 1. 转为灰度图片
        let img = dynamic_image_to_mat_gray(image)?;

        // 2. 创建 ORB 特征检测器
        let mut orb = ORB::create(500, 1.2, 8, 31, 0, 2, features2d::ORB_ScoreType::HARRIS_SCORE, 31, 20)?;

        // 3. 检测并计算特征
        let mut kp = Vector::new();
        let mut desc = Mat::default();
        orb.detect_and_compute(&img, &Mat::default(), &mut kp, &mut desc, false)?;

        Ok(Self {
            kp_len: kp.len(),
            desc
        })
    }

    /// 计算两个图像的相似度
    ///
    ///
    /// k - 最近邻匹配（k-nearest neighbor matching） 是一种基础且常用的匹配策略，核心思想是：
    /// 为每个 “待查询的特征描述子”，从 “参考描述子集合” 中找到最相似的前 k 个描述子，以此为后续的匹配筛选提供依据
    ///
    ///
    pub fn distance(&self, other: &OrbFeature) -> Result<(usize, f64)> {
        // 1. 匹配描述子
        // 使用暴力匹配器（BFMatcher）对两个图像的 ORB 描述子进行 k - 最近邻匹配，为每个描述子找到 2 个最相似的候选匹配
        let matcher = BFMatcher::new(NORM_HAMMING, false)?;
        let mut matches = Vector::new();
        matcher.knn_train_match(&self.desc, &other.desc, &mut matches, 2, &Mat::default(), true)?;

        // 2. 过滤错误匹配
        let mut good_matches = Vector::<DMatch>::new();
        for m in matches {
            if m.len() >= 2 {
                let m1 = m.get(0)?; // 最佳匹配
                let m2 = m.get(1)?; // 次佳匹配
                if m1.distance < m2.distance * 0.7 {
                    good_matches.push(m1);
                }
            }
        }

        // 3. 相似度计算
        let total_kp = std::cmp::min(self.kp_len, other.kp_len);
        let similarity = if total_kp > 0 {
            good_matches.len() as f64 / total_kp as f64
        } else {
            0.0
        };

        Ok((good_matches.len(),  similarity))
    }
}

/// 转换灰度图（单通道）
fn dynamic_image_to_mat_gray(img: DynamicImage) -> Result<Mat> {
    // 转换为灰度图（L8 格式：单通道，8位）
    let gray_img = img.to_luma8();
    let (width, height) = (gray_img.width() as i32, gray_img.height() as i32);
    let data = gray_img.into_raw();

    // 创建单通道 Mat
    let mat = Mat::new_rows_cols_with_data(height, width, &data)?;
    // 复制数据确保所有权
    let mut cloned_mat = Mat::default();
    mat.copy_to(&mut cloned_mat)?;

    Ok(cloned_mat)
}

mod test {
    use super::*;

    #[test]
    fn test_orb_feature() {
        let img1 = image::open(r"C:\Users\12618\Desktop\tmp\test\1.png").unwrap();
        let orb1 = OrbFeature::from(img1).unwrap();
        let img2 = image::open(r"C:\Users\12618\Desktop\tmp\test\2.png").unwrap();
        let orb2 = OrbFeature::from(img2).unwrap();
        let (count, similarity) = orb1.distance(&orb2).unwrap();
        println!("count: {}, similarity: {}", count, similarity);
        assert!(similarity > 1.0);
    }
}