use std::collections::HashMap;
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
    pub datas: Vec<TarPdfResultMsg>,
    pub tags: Vec<String>,
}

#[derive(Debug, Default, Serialize, Deserialize, SignalPiece)]
pub struct TarPdfResultMsg {
    pub file_name: String,
    // k: tag value: (value, errorMsg)
    pub datas: HashMap<String, (String, String)>,
    pub template_result: String,
    pub error: String,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct OcrConfigMsg {
    pub url: String,
    pub api_key: String,
    pub passwd: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct RefOcrDatasMsg {
    pub data: Vec<OcrDataMsg>,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct OcrDataMsg {
    pub id: String,
    pub text: String,
    pub location: BoxPositionMsg,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct BoxPositionMsg {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct RenameFileMsg {
    // 0: filename 1: error
    pub value: Vec<(String, String)>,
}