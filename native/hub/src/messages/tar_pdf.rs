use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct TarPdfMsg {
    pub(crate) now: u32,
    pub(crate) sum: u32,
    pub(crate) current_file: String,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct TarPdfResultsMsg {
    pub datas: Vec<TarPdfResultMsg>
}

#[derive(Debug, Default, Serialize, Deserialize, SignalPiece)]
pub struct TarPdfResultMsg {
    pub file_name: String,
    pub title: String,
    pub company: String,
    pub no: String,
    pub pages: i32,
    pub error_msg: String,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct OcrConfigMsg {
    pub url: String,
    pub api_key: String,
    pub passwd: Option<String>,
    pub no_regex: Vec<String>,
    pub export_file_name_rule: String,
}