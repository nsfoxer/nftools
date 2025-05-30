pub mod api;

use rinf::{DartSignalBinary, RustSignalBinary};
use serde::{Deserialize, Serialize};

// 基础请求
// 请求体 位于binary字段响应体中
#[derive(Debug, Deserialize, DartSignalBinary)]
pub struct BaseRequest {
    // 请求 id
    pub id: u32,
    // 请求服务
    pub service: String,
    // 请求方法
    pub func: String,
    // 是否为流式请求
    pub is_stream: bool,
}

// 基础响应
// 响应体 位于binary字段响应体中
#[derive(Debug, Serialize, RustSignalBinary)]
pub struct BaseResponse {
    // 响应 id
    pub id: u32,
    // 响应错误信息,当存在时，则response无意义
    pub msg: String,
    // 是否为流式响应
    pub is_stream: bool,
    // 流式响应是否结束
    pub is_end: bool,
}