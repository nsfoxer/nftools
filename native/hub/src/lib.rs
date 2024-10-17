//! This `hub` crate is the
//! entry point of the Rust logic.

mod api;
mod common;
mod messages;
mod service;
mod r#do;
mod dbus;

use std::sync::Arc;
use log::error;
use crate::api::api::ApiService;
use crate::common::*;
use crate::messages::base::BaseRequest;
use crate::service::display::display::{DisplayLight, DisplayMode};
use rinf::debug_print;
use tokio;
use common::global_data::GlobalData;
use crate::service::syncfile::SyncFile;

rinf::write_interface!();

async fn main() {
    debug_print!("lib start");
    let global_data = GlobalData::new().expect("Global data initialized");
    tokio::spawn(base_request(global_data));
    debug_print!("lib end");
}

async fn init_service(gd: Arc<GlobalData>) -> ApiService {
    let mut api = ApiService::new();

    #[cfg(target_os = "windows")]
    {
        api.add_imm_service(Box::new(DisplayLight::new()));
        api.add_lazy_service(Box::new(DisplayMode::new()));
    }

    #[cfg(target_os = "linux")]
    {
        if let Some(display) = DisplayLight::new().await {
            api.add_service(Box::new(display));
        } else {
            error!("display light 服务创建失败");
        }
        
        match DisplayMode::default() {
            Ok(mode) => api.add_service(Box::new(mode)),
            Err(e) => error!("display mode服务创建失败。原因:{e}"),
        }
    }
    api.add_service(Box::new(SyncFile::new(gd.clone())));

    api
}

async fn base_request(gd: GlobalData) -> Result<()> {
    let gd = Arc::new(gd);
    let api = init_service(gd.clone()).await;
    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        debug_print!("Received message {:?}", &signal.message);
        api.handle(signal);
    }

    Ok(())
}
