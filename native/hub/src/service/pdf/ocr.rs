use std::cmp::max;
use anyhow::{anyhow, Result};
use reqwest_dav::re_exports::serde::Deserialize;
use serde_with::serde_as;
use serde_with::DisplayFromStr;
use strsim::levenshtein;
use crate::messages::tar_pdf::BoxPositionMsg;

/// 阈值比例
const DISTANCE_RATIO: f64 = 0.6;
const TEXT_SIMILARITY_RATIO: f64 = 0.4;
const MIN_TEXT_LEN: usize = 3;

/// 远端OCR识别结果
#[derive(Debug, Deserialize)]
pub struct OcrResult {
    pub result: OcrTexts,
}

#[serde_as]
#[derive(Debug, Deserialize)]
pub struct OcrTexts {
    texts: Vec<String>,
    #[serde_as(as = "Vec<DisplayFromStr>")]
    scores: Vec<f64>,
    boxes: Vec<BoxPosition>,
}
impl OcrTexts {
    /// 转换为OCR识别数据
    pub fn into_ocr_data(self) -> Vec<OcrData> {
        let boxes = self.boxes;
        let mut texts = Vec::with_capacity(boxes.len());
        for (text, location) in self.texts.into_iter().zip(boxes.into_iter()) {
            texts.push(OcrData {
                text,
                location,
            });
        }
        texts
    }
}

#[serde_as]
#[derive(Debug, Deserialize, Clone)]
pub struct BoxPosition {
    #[serde_as(as = "DisplayFromStr")]
    x: f64,
    #[serde_as(as = "DisplayFromStr")]
    y: f64,
    #[serde_as(as = "DisplayFromStr")]
    width: f64,
    #[serde_as(as = "DisplayFromStr")]
    height: f64,
}

impl OcrResult {
    /// 去除不准确的数据
    pub fn clear_fuzzy_data(&mut self) {
        let mut locations = Vec::new();
        for (i, scores) in self.result.scores.iter().enumerate() {
            if *scores < 0.96 || self.result.texts[i].chars().count() < MIN_TEXT_LEN {
                locations.push(i);
            }
        }
        // 删除坐标在locations之内的数据
        for i in locations.iter().rev() {
            self.result.texts.remove(*i);
            self.result.scores.remove(*i);
            self.result.boxes.remove(*i);
        }
    }
}

/// OCR识别数据
#[derive(Clone)]
pub struct OcrData {
    pub text: String,
    pub location: BoxPosition,
}

impl OcrData {

    /// 查找与当前文本相似的文本
    /// 依据location及文本相似度
    ///
    /// texts: 要查找的所有文本列表
    ///
    /// min_score: 最小相似度
    pub fn find_similar_text<'a>(
        &self,
        texts: &'a Vec<OcrData>,
        min_score: f64,
    ) -> Result<Option<&'a OcrData>> {
        // 1. 计算参考值的中心坐标
        let (ref_x, ref_y) = (
            (self.location.x + self.location.width) / 2.0,
            (self.location.y + self.location.height) / 2.0,
        );

        // 2. 计算可能的最大距离
        let max_x = texts.iter().map(|x| x.location.x+x.location.width)
            .max_by(|a, b| a.total_cmp(b)).ok_or_else(|| anyhow!("无法查找到最大值"))?;
        let max_y = texts.iter().map(|x| x.location.y+x.location.height)
            .max_by(|a, b| a.total_cmp(b)).ok_or_else(|| anyhow!("无法查找到最大值"))?;
        let max_distance = ((max_x - ref_x).powi(2) + (max_y - ref_y).powi(2)).sqrt();

        // 3. 计算各个评分
        let mut result = None;
        let mut max_score = 0.0;
        for text in texts.iter() {
            let score = Self::cal_score(ref_x, ref_y, self.text.as_str(), max_distance, min_score, text)?;
            if score > max_score {
                max_score = score;
                result = Some(text);
            }
        }

        Ok(result)
    }

    fn cal_score(ref_x: f64, ref_y: f64, ref_text: &str, max_distance: f64, min_score: f64, text: &OcrData) -> Result<f64> {
        // 1. 计算目标值的中心坐标
        let (target_x, target_y) = (
            (text.location.x + text.location.width) / 2.0,
            (text.location.y + text.location.height) / 2.0,
            );

        // 2. 计算距离评分
        let distance = ((target_x-ref_x).powi(2) + (target_y-ref_y).powi(2)).sqrt();
        let distance_score =  0.0f64.max(1.0f64 - distance / max_distance);

        // 3. 筛选掉距离评分低于阈值的数据
        if ref_text.len() < MIN_TEXT_LEN || text.text.len() < MIN_TEXT_LEN {
            return Ok(distance_score);
        }
        if distance_score * DISTANCE_RATIO + TEXT_SIMILARITY_RATIO < min_score {
            return Ok(0.0);
        }

        // 4. 计算文本相似度评分
        let text_similar = levenshtein(ref_text, text.text.as_str());
        let text_similar_score = 1.0 - (text_similar as f64 / max(ref_text.len(), text.text.len()) as f64);

        Ok(distance_score * DISTANCE_RATIO + text_similar_score * TEXT_SIMILARITY_RATIO)
    }
}


impl From<BoxPosition> for BoxPositionMsg {
    fn from(value: BoxPosition) -> Self {
        Self {
            x: value.x,
            y: value.y,
            width: value.width,
            height: value.height,
        }
    }
}