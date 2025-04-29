use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

// 压缩图片请求
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct CompressLocalPicMsg {
    pub local_file: String,
    pub width: u32,
    pub height: u32,
}