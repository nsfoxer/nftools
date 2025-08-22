use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct EmptyMsg {
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct StringMsg {
    pub value: String,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct PairStringMsg {
    pub key: String,
    pub value: String,
}
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct VecStringMsg {
    pub values: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct UintFiveMsg {
    pub value: u32,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct BoolMsg {
    pub value: bool,
}
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct DoubleMsg  {
    pub value: f64,
}
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct DataMsg  {
    pub value: Vec<u8>,
}
