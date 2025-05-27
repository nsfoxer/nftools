use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

// 压缩图片请求
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct CompressLocalPicMsg {
    // 图片位置
    pub local_file: String,
    // 想要压缩的宽度
    pub width: u32,
    // 想要压缩的高度
    pub height: u32,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct CompressLocalPicRspMsg {
    // 压缩后的图片位置
    pub local_file: String,
    // 压缩后实际图片宽度
    pub width: u32,
    // 压缩后实际图片高度
    pub height: u32,
}

// 二维码图像识别数据
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct QrCodeDataMsg  {
    // 左上角点
    pub tl: (i32, i32),
    // 右上角点
    pub tr: (i32, i32),
    // 右下角点
    pub br: (i32, i32),
    // 左下角点
    pub bl: (i32, i32),
    // 二维码数据
    pub data: Vec<u8>,
}

// 二维码图像识别数据列表
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct QrCodeDataMsgList  {
    // 二维码数据列表
    pub value: Vec<QrCodeDataMsg>,
    // 图像宽度
    pub image_width: u32,
    // 图像高度
    pub image_height: u32,
}