use reqwest_dav::re_exports::serde::{Deserialize, Serialize};
use rinf::SignalPiece;

/// 图片裁剪请求 rect
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct ImageSplitReqMsg {
    /// 标记图片
    pub mark_image: String,
    /// 标记类型
    pub mark_type: MarkTypeMsg,
    /// 添加的颜色
    pub add_color: ColorMsg,
    /// 删除的颜色 对Path无效
    pub del_color: ColorMsg,
}

/// 图片裁剪类型
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub enum MarkTypeMsg {
    Path,
    Rect,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize, SignalPiece)]
pub struct ColorMsg {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
struct ImageSplitRspMsg {
    /// 处理后的图片
    image: String,
}