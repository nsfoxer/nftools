//! This `hub` crate is the
//! entry point of the Rust logic.

mod common;
mod messages;
mod service;
mod api;

use rinf::debug_print;
use crate::api::api::ApiService;
use crate::common::*;
use crate::messages::base::BaseRequest;
use tokio;
use crate::service::display::display_light::DisplayLight;

rinf::write_interface!();

async fn main() {
    tokio::spawn(base_request());
}

fn init_service() -> ApiService {
    let mut api = ApiService::new();
    
    api.add_imm_service(Box::new(DisplayLight{
    }));
    
    api
}

async fn base_request() -> Result<()> {
    let api = init_service();
    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        debug_print!("Received message {:?}", &signal.message);
        api.handle(signal);
    }

    Ok(())
}