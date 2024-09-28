//! This `hub` crate is the
//! entry point of the Rust logic.

mod common;
mod messages;
mod service;
mod api;

use rinf::debug_print;
use crate::common::*;
use crate::messages::base::{BaseRequest, BaseResponse};

rinf::write_interface!();

async fn main() {
    tokio::spawn(base_request());
}

async fn base_request() -> Result<()> {
    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        let msg = signal.message;
        debug_print!("{:?}", msg);
    }

    Ok(())
}