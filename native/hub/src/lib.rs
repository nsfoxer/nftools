//! This `hub` crate is the
//! entry point of the Rust logic.

mod common;
mod messages;
mod service;

use std::time::Duration;
use prost::Message;
use rinf::debug_print;
use crate::common::*;
use tokio;
use crate::messages::base::{BaseRequest, BaseResponse};
use crate::messages::display::DisplaySupport;

rinf::write_interface!();

async fn main() {
    tokio::spawn(base_request());
}

async fn base_request() -> Result<()> {
    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        let msg = signal.message;
        debug_print!("{:?}", msg);
        if msg.service == "display" {
            BaseResponse {
                id: msg.id,
                msg: "".to_string(),
                response: DisplaySupport{
                    support: true,
                }.encode_to_vec(),
            }.send_signal_to_dart();
        }
    }

    Ok(())
}