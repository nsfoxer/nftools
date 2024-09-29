//! This `hub` crate is the
//! entry point of the Rust logic.

mod common;
mod messages;
mod service;
mod api;

use std::sync::atomic::{AtomicU8, AtomicUsize};
use rinf::debug_print;
use crate::api::api::ApiService;
use crate::common::*;
use crate::messages::base::{BaseRequest, BaseResponse};
use crate::messages::display::DisplaySupport;
use crate::service::display::DisplayInfo;
use tokio;

rinf::write_interface!();

async fn main() {
    tokio::spawn(base_request());
}

fn init_service() -> ApiService {
    let mut api = ApiService::new();
    
    api.add_imm_service(Box::new(DisplayInfo{
    }));
    
    api
}

async fn base_request() -> Result<()> {
    let api = init_service();
    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        let msg = signal.message;
        debug_print!("{:?}", msg);
        api.handle(msg);
    }

    Ok(())
}