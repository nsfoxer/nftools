//! This `hub` crate is the
//! entry point of the Rust logic.

mod api;
mod common;
mod messages;
mod service;
mod dbus;

use std::any::Any;
use std::sync::Arc;
use anyhow::anyhow;
use log::error;
use process_lock::{LockGuard, ProcessLock};
use rinf::debug_print;
use crate::api::api::ApiService;
use crate::common::*;
use crate::messages::base::BaseRequest;
use crate::service::display::display_os::{DisplayLight, DisplayMode};
use tokio;
use common::global_data::GlobalData;
use crate::service::syncfile::SyncFileService;
use crate::service::system_info::SystemInfoService;
use crate::service::utils::UtilsService;

rinf::write_interface!();

async fn main() {
    let global_data = GlobalData::new().expect("Global data initialized");
    tokio::spawn(base_request(global_data));
}

async fn init_service(gd: Arc<GlobalData>) -> ApiService {
    let mut api = ApiService::new();
    api.add_imm_service(Box::new(UtilsService::new()));

    let lg = match lock() {
        Ok(r) => {r}
        Err(_e) => {
            return api;
        }
    };

    #[cfg(target_os = "windows")]
    {
        api.add_imm_service(Box::new(DisplayLight::new()));
        api.add_lazy_service(Box::new(DisplayMode::new(gd.clone()).await));
    }
    lg.type_id();
    #[cfg(target_os = "linux")]
    {
        if let Some(display) = DisplayLight::new().await {
            api.add_service(Box::new(display));
        } else {
            error!("display light 服务创建失败");
        }
        
        match DisplayMode::new(gd.clone()).await {
            Ok(mode) => api.add_service(Box::new(mode)),
            Err(e) => error!("display mode服务创建失败。原因:{e}"),
        }
    }
    match SyncFileService::new(gd.clone()) {
        Ok(s) => {api.add_service(Box::new(s));}
        Err(e) => {
            error!("sync file服务创建失败：原因:{e}");
        }
    }
    api.add_service(Box::new(SystemInfoService::new().await));

    api
}

async fn base_request(gd: GlobalData) -> Result<()> {
    let gd = Arc::new(gd);
    let api = init_service(gd.clone()).await;

    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        api.handle(signal);
    }

    Ok(())
}

/// 加锁成功，则返回lg，否则，返回Err
fn lock() -> anyhow::Result<LockGuard> {
    let mut path = utils::get_user_name();
    path.push_str(APP_NAME);
    path.push_str(".lock");
    let lock = ProcessLock::new(path, None)?;
    let lg = lock.trylock()?.ok_or(anyhow!("lock"))?;
    Ok(lg)
}