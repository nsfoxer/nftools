use std::io::Write;

use anyhow::Result;
use dirs::data_local_dir;
use prost::Message;
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};
use tokio::fs::File;
use tokio::io::AsyncReadExt;

use crate::{func_end, func_notype};
use crate::common::utils::second_timestamp;
use crate::messages::system_info::{ChartInfo, ChartInfoRsp, SystemInfoCache};
use crate::service::service::Service;

/// 系统信息服务
pub struct SystemInfoService {
    /// 系统信息读取
    sys: System,
    /// cpu所有数据
    cpu_datas: Vec<ChartInfo>,
    /// mem所有数据
    mem_datas: Vec<ChartInfo>,
}

#[async_trait::async_trait]
impl Service for SystemInfoService {
    fn get_service_name(&self) -> &'static str {
        "SystemInfo"
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_notype!(self, func, get_cpu, get_ram);
        func_end!(func)
    }
}

impl SystemInfoService {
    fn get_cpu(&mut self) -> Result<ChartInfo> {
        let value = (self.sys.global_cpu_usage() * 10000.0) as u32;
        self.sys.refresh_cpu_usage();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value,
        };
        self.add_cpu_info(info.clone());
        Ok(info)
    }

    fn get_ram(&mut self) -> Result<ChartInfo> {
        self.sys.refresh_memory();
        let value = self.sys.used_memory() * 1000 / self.sys.total_memory();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value: value as u32,
        };
        self.add_mem_info(info.clone());
        Ok(info)
    }
}

impl SystemInfoService {
    pub async fn new() -> Self {
        let res = RefreshKind::new()
            .with_cpu(CpuRefreshKind::everything())
            .with_memory(MemoryRefreshKind::new().with_ram());
        let mut sys = System::new_with_specifics(res);
        sys.refresh_all();
        
        let (cpu_datas, memory_datas) = Self::load_datas().await;
        
        Self {
            sys,
            cpu_datas,
            mem_datas: memory_datas
        }
    }

    async fn load_datas() -> (Vec<ChartInfo>, Vec<ChartInfo>) {
        let mut path= data_local_dir().unwrap_or_default();
        path.push("system_info.cache");

        let mut cpu_datas = Vec::new();
        let mut mem_datas = Vec::new();
        if let Ok(mut file) = File::open(path).await {
            // SystemInfoCache::decode();
            let mut buf = Vec::new();
            let _ = file.read_to_end(&mut buf).await;
            if let Ok(r)  = SystemInfoCache::decode(&buf[..]) {
                cpu_datas = r.cpu_datas.unwrap_or_default().infos;
                mem_datas = r.mem_datas.unwrap_or_default().infos;
            }
        }

        (cpu_datas, mem_datas)
    }

    fn add_cpu_info(&mut self, info: ChartInfo) {
        self.cpu_datas.push(info);
    }
    fn add_mem_info(&mut self, info: ChartInfo) {
        self.cpu_datas.push(info);
    }
}

impl Drop for SystemInfoService {
    fn drop(&mut self) {
        let mut path= data_local_dir().unwrap_or_default();
        path.push("system_info.cache");

        let cache = SystemInfoCache{
            mem_datas: Some(ChartInfoRsp{
                infos: self.mem_datas.clone(),
            }),
            cpu_datas: Some(ChartInfoRsp{
                infos: self.cpu_datas.clone(),
            }),
        };

        let buf = cache.encode_to_vec();
        if let  Ok(mut file) = std::fs::File::create(path) {
            let _ = file.write_all(&buf);
        }

    }
}