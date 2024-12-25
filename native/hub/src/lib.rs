//! This `hub` crate is the
//! entry point of the Rust logic.

mod api;
mod common;
mod dbus;
mod messages;
mod service;

use crate::api::api::ApiService;
use crate::common::*;
use crate::messages::base::BaseRequest;
use crate::service::display::display_os::{DisplayLight, DisplayMode};
use crate::service::syncfile::SyncFileService;
use crate::service::system_info::SystemInfoService;
use crate::service::utils::UtilsService;
use anyhow::anyhow;
use common::global_data::GlobalData;
use log::error;
use rinf::debug_print;
use std::any::Any;
use std::path::PathBuf;
use std::sync::Arc;
use sysinfo::{Pid, Process, ProcessRefreshKind, RefreshKind, System};
use tokio;
use crate::common::utils::notify;
use crate::service::ai::BaiduAiService;

rinf::write_interface!();

async fn main() {
    tokio::spawn(base_request());
}

async fn init_service(gd: Arc<GlobalData>) -> ApiService {
    let mut api = ApiService::new();
    api.add_imm_service(Box::new(UtilsService::new()));


    #[cfg(target_os = "windows")]
    {
        api.add_imm_service(Box::new(DisplayLight::new()));
        api.add_lazy_service(Box::new(DisplayMode::new(gd.clone()).await));
    }
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
        Ok(s) => {
            api.add_service(Box::new(s));
        }
        Err(e) => {
            error!("sync file服务创建失败：原因:{e}");
        }
    }
    api.add_service(Box::new(SystemInfoService::new().await));
    
    api.add_stream_service(Box::new(BaiduAiService::new()));

    api
}

async fn base_request() -> Result<()> {
    let path = lock().ok();
    let global_data = GlobalData::new(path).expect("Global data initialized");
    let gd = Arc::new(global_data);
    let api = init_service(gd.clone()).await;

    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        api.handle(signal);
    }

    Ok(())
}

/// 加锁成功，则返回lg，否则，返回Err
fn lock() -> anyhow::Result<PathBuf> {
    let process = System::new_with_specifics(
        RefreshKind::new().with_processes(ProcessRefreshKind::everything()),
    );
    let mut path = utils::get_cache_dir()?;
    for entry in std::fs::read_dir(&path)? {
        if let Ok(entry) = entry {
            let path = entry.path().to_str().unwrap_or_default().to_string();
            let filename = entry.file_name();
            let filename = filename.to_str().unwrap_or_default();
            if path.ends_with(".lock") {
                let path1 = filename.strip_suffix(".lock").unwrap();
                let paths: Vec<&str> = path1.splitn(2, "_^_^_").collect();
                if paths.len() != 2 {
                    std::fs::remove_file(&path)?;
                    continue;
                }
                let name = paths[0];
                let pid = paths[1].parse::<u32>();
                if pid.is_err() {
                    std::fs::remove_file(&path)?;
                    continue;
                }
                let pid = pid.unwrap();
                match process.process(Pid::from_u32(pid)) {
                    None => {
                        std::fs::remove_file(&path)?;
                        continue;
                    }
                    Some(p) => {
                        let pname = p.name().to_str().unwrap_or_default();
                        if pname != name {
                            std::fs::remove_file(&path)?;
                            continue;
                        } else {
                            // 已在运行 kill me
                            let _ = notify(format!("{}已在运行中", APP_NAME).as_str());
                            std::process::exit(0);
                        }
                    }
                }
            }
        }
    }
    let pid = std::process::id();
    let name = match process.process(Pid::from_u32(pid)) {
        None => {""}
        Some(p) => {p.name().to_str().unwrap_or_default()}
    };
    path.push(format!("{name}_^_^_{pid}.lock"));
    let _ = std::fs::File::create(&path)?;
    Ok(path)
}

mod test {
    use crate::lock;

    #[test]
    fn s() {
        let result = lock();
        eprintln!("{:?}", result);
        let result = lock();
        eprintln!("{:?}", result);
    }
}