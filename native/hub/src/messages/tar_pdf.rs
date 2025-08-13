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

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct TarPdfResultMsg {
    pub file_name: String,
    pub title: String,
    pub error_msg: String,
}