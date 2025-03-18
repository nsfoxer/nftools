//! This `hub` crate is the
//! entry point of the Rust logic.

mod api;
mod common;
mod dbus;
mod messages;
mod service;

use crate::api::api::ApiService;
use crate::common::utils::notify;
use crate::common::*;
use crate::messages::base::BaseRequest;
use crate::service::ai::BaiduAiService;
use crate::service::display::display_os::{DisplayLight, DisplayMode};
use crate::service::settings::about::AboutService;
use crate::service::settings::autostart::AutoStartService;
use crate::service::syncfile::SyncFileService;
use crate::service::utils::UtilsService;
use anyhow::anyhow;
use common::global_data::GlobalData;
use log::error;
use std::path::PathBuf;
use sysinfo::{Pid, ProcessRefreshKind, RefreshKind, System};
use tokio;

rinf::write_interface!();

async fn main() {
    tokio::spawn(base_request());
}

async fn init_service(gd: GlobalData) -> ApiService {
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
    match SyncFileService::new(gd.clone()).await {
        Ok(s) => {
            api.add_service(Box::new(s));
        }
        Err(e) => {
            error!("sync file服务创建失败：原因:{e}");
        }
    }
    match AutoStartService::new() {
        Ok(service) => api.add_imm_service(Box::new(service)),
        Err(e) => error!("autostart服务创建失败 原因:{}", e),
    };

    api.add_service(Box::new(AboutService::new()));
    api.add_stream_service(Box::new(BaiduAiService::new(gd.clone()).await));

    api
}

async fn base_request() -> Result<()> {
    let path = lock().ok();
    let global_data = GlobalData::new().await.expect("Global data initialized");
    let gd = global_data;
    let api = init_service(gd.clone()).await;

    let mut receiver = BaseRequest::get_dart_signal_receiver()?;
    let mut close_signal = None;
    while let Some(signal) = receiver.recv().await {
        if signal.message.service == "BaseService" && signal.message.func == "close" {
            close_signal = Some(api.close(signal).await);
            log::info!("服务已全部停止");
            break;
        }
        api.handle(signal);
    }

    // 尝试删除lock
    if let Some(path) = path {
        tokio::fs::remove_file(path)
            .await
            .unwrap_or_else(|e| eprintln!("{}", e));
    }

    // 回应关闭信息
    if let Some(close_signal) = close_signal {
        close_signal.send_signal_to_dart(Vec::with_capacity(0));
    }

    Ok(())
}

/// 加锁成功，则返回lg，否则，返回Err
fn lock() -> anyhow::Result<PathBuf> {
    if cfg!(debug_assertions) {
        return Err(anyhow!("测试环境不开启lock file"));
    }
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
        None => "",
        Some(p) => p.name().to_str().unwrap_or_default(),
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
