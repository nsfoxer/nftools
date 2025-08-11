use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct TarPdfMsg {
    pub(crate) now: u32,
    pub(crate) sum: u32,
    pub(crate) current_file: String,
}
