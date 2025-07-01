use reqwest_dav::re_exports::serde::{Deserialize, Serialize};
use rinf::SignalPiece;

/// 图片裁剪请求 rect
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct ImageSplitReqMsg {
    /// 原始处理图片路径
    original_image: String,
    /// 标记图片
    mark_image: String,
    /// 标记类型
    mark_type: MarkTypeMsg,
    /// 添加的颜色
    add_color: ColorMsg,
    /// 删除的颜色 对Path无效
    del_color: ColorMsg,
}

/// 图片裁剪类型
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub enum MarkTypeMsg {
    Path,
    Rect,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct ColorMsg {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
struct ImageSplitRspMsg {
    /// 处理后的图片
    image: String,
}