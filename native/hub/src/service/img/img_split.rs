use crate::service::service::Service;
use opencv::prelude::*;
use crate::{func_end, func_nono};

#[derive(Debug)]
pub struct ImageSplit {
    original_image: Mat,
    bgd_model: Mat,
    fgd_model: Mat,
    mask: Mat,
}

#[async_trait::async_trait]
impl Service for ImageSplit {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> anyhow::Result<Option<Vec<u8>>> {
        // func_nono!(self, func, reset);
        func_end!(func)
    }
}

impl ImageSplit {
    /// new
    pub fn new() -> Self {
        Self {
            original_image: Mat::default(),
            bgd_model: Mat::default(),
            fgd_model: Mat::default(),
            mask: Mat::default(),
        }
    }

    /// 重置数据
    fn reset(&mut self) {
        self.original_image = Mat::default();
        self.bgd_model = Mat::default();
        self.fgd_model = Mat::default();
        self.mask = Mat::default();
    }

}