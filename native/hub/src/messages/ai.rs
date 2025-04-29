use reqwest_dav::re_exports::serde::{Deserialize, Serialize};
use rinf::SignalPiece;

// 百度AI响应
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct BaiduAiRspMsg {
    pub content: String,
}

// 设置API Key与应用Secret Key
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct BaiduAiKeyReqMsg {
    pub api_key: String,
    pub secret: String,
}

// 所有的对话列表
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct QuestionListMsg {
    pub question_list: Vec<QuestionMsg>,
}

// 一个问题条目
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct QuestionMsg {
    // id
    pub id: u32,
    // 简要描述
    pub desc: String,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct AiModelMsg {
    pub model_enum: ModelEnumMsg,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub enum ModelEnumMsg {
    Baidu = 0,
    Spark = 1,
}
