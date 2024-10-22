use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};
use crate::service::service::{LazyService, Service};
use anyhow::Result;
use crate::{func_end, func_notype};
use prost::Message;
use crate::common::utils::second_timestamp;
use crate::messages::system_info::{ChartInfo};
#[derive(Default)]
pub struct SystemInfoService {
    sys: Option<System>,
    history_datas: Option<Vec<ChartInfo>>,
}

#[async_trait::async_trait]
impl Service for SystemInfoService {
    fn get_service_name(&self) -> &'static str {
        "SystemInfo"
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> anyhow::Result<Option<Vec<u8>>> {
        func_notype!(self, func, get_cpu, get_ram);
        func_end!(func)
    }
}

#[async_trait::async_trait]
impl LazyService for SystemInfoService {
    async fn lazy_init_self(&mut self) -> Result<()> {
        // 初始化监控信息
        let res = RefreshKind::new()
            .with_cpu(CpuRefreshKind::everything())
            .with_memory(MemoryRefreshKind::new().with_ram());
        let mut sys = System::new_with_specifics(res);
        sys.refresh_all();
        self.sys = Some(sys);
        Ok(())
    }
}


impl SystemInfoService {
    fn get_cpu(&mut self) -> Result<ChartInfo> {
        let sys = self.sys.as_mut().unwrap();
        let value = (sys.global_cpu_usage() * 10000.0) as u32;
        sys.refresh_cpu_usage();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value,
        };

        Ok(info)
    }

    fn get_ram(&mut self) -> Result<ChartInfo> {
        let sys = self.sys.as_mut().unwrap();
        sys.refresh_memory();
        let value = sys.used_memory() * 1000 / sys.total_memory();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value: value as u32,
        };

        Ok(info)
    }
}

impl SystemInfoService {
    fn add_cpu_infos() {

    }
}

impl Drop for SystemInfoService {
    fn drop(&mut self) {
        todo!()
    }
}