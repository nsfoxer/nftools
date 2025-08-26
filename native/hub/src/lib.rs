//! This `hub` crate is the
//! entry point of the Rust logic.

mod api;
mod common;
mod dbus;
mod messages;
mod service;

use crate::api::BaseRequest;
use crate::api::api::ApiService;
use crate::common::utils::{get_cache_dir, notify};
use crate::common::*;
use anyhow::anyhow;
use common::global_data::GlobalData;
use convert_case::{Case, Casing};
use log::{error, info};
use mimalloc::MiMalloc;
use rinf::{DartSignalBinary, RustSignalBinary, dart_shutdown};
use simple_log::LogConfigBuilder;
use std::path::PathBuf;
use sysinfo::{Pid, ProcessRefreshKind, RefreshKind, System};
use tokio;

rinf::write_interface!();

#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

fn init_log() -> Result<()> {
    let mut log_file = get_cache_dir()?;

    log_file.push("nftools.log");
    let config = LogConfigBuilder::builder()
        .path(log_file.to_str().unwrap_or_default().to_string())
        .size(1 * 100)
        .roll_count(100)
        .time_format("%Y-%m-%d %H:%M:%S.%f") //E.g:%H:%M:%S.%f
        .level(if cfg!(debug_assertions) {
            "debug"
        } else {
            "info"
        })?
        .output_file()
        .output_console()
        .build();
    simple_log::new(config)?;

    Ok(())
}

#[tokio::main]
async fn main() {
    if let Err(e) = init_log() {
        eprintln!("日志初始化失败: {}", e);
    }
    info!("后端初始化开始");
    tokio::spawn(async {
        if let Err(e) = base_request().await {
            error!("后端启动失败: {}", e);
        }
    });
    dart_shutdown().await;
    info!("APP停止");
}

async fn base_request() -> Result<()> {
    let path = lock().ok();
    let global_data = GlobalData::new().await.expect("Global data initialized");
    let gd = global_data;
    let mut api = ApiService::new(gd);

    let receiver = BaseRequest::get_dart_signal_receiver();
    let mut close_signal = None;
    while let Some(mut signal) = receiver.recv().await {
        signal.message.func = signal.message.func.trim().to_case(Case::Snake);
        info!(
            "收到信号: service={}, func={}",
            signal.message.service, signal.message.func,
        );
        let signal = signal;
        // Api 服务特殊处理
        if signal.message.service == "ApiService" {
            // close处理
            if signal.message.func == "close" {
                close_signal = Some(api.close(signal).await);
                info!("服务已全部停止");
                break;
            }
            // api其他情况处理
            api.api_handle(signal).await;
            continue;
        }
        // 通常服务处理
        api.handle(signal);
    }
    info!("后端服务已停止");

    // 尝试删除lock
    if let Some(path) = path {
        tokio::fs::remove_file(path)
            .await
            .unwrap_or_else(|e| error!("{}", e));
    }
    info!("成功删除lock文件");

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
    let mut path = get_cache_dir()?;
    for entry in std::fs::read_dir(&path)? {
        if let Ok(entry) = entry {
            let path = entry.path().to_str().unwrap_or_default().to_string();
            let filename = entry.file_name();
            let filename = filename.to_str().unwrap_or_default();
            if path.ends_with(".lock") {
                let path1 = filename.strip_suffix(".lock").unwrap();
                let paths: Vec<&str> = path1.splitn(2, "_^o^_").collect();
                if paths.len() != 2 {
                    continue;
                }
                let name = paths[0];
                let pid = paths[1].parse::<u32>();
                if pid.is_err() {
                    std::fs::remove_file(&path)?;
                    continue;
                }
                let pid = pid?;
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
    path.push(format!("{name}_^o^_{pid}.lock"));
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
