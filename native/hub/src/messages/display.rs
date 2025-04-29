use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

// display支持
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct DisplaySupportMsg {
    pub support: bool,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct DisplayInfoMsg {
    // 屏幕名称
    pub screen: String,
    // 亮度
    pub value: u32,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct DisplayModeMsg {
    pub is_light: bool,
}

// 请求亮度信息
// 请求体：无
// 响应
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct DisplayInfoReqMsg {
    pub infos: Vec<DisplayInfoMsg>,
}

// --------------  亮色暗色+壁纸 ------------

// 请求亮度信息
// 请求体 无
// 响应
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct GetDisplayModeRspMsg {
    pub mode: DisplayModeMsg,
}

// 设置主题亮色/暗色
// 请求体 
// 响应 无
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct SetDisplayModeReqMsg {
    pub mode: DisplayModeMsg,
}

// 获取壁纸信息
// 请求体 无
// 响应
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct GetWallpaperRspMsg {
    pub light_wallpaper: String,
    pub dark_wallpaper: String,
}

// 设置系统是否常亮不睡眠 请求和回应
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct SystemModeMsg {
    // 是否开启此功能
    pub enabled: bool,
    // 屏幕是否常亮 为否时，系统工作但不休眠；为真时，屏幕常亮
    pub keep_screen: bool,
}