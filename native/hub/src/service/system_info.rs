use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};
use crate::messages::common::{FloatMessage};
use crate::service::service::{LazyService, Service};
use anyhow::Result;
use crate::{func_end, func_notype};
use prost::Message;

#[derive(Default)]
pub struct SystemInfoService {
    sys: Option<System>,
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
    async fn lazy_init_self(&mut self) -> anyhow::Result<()> {
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
    fn get_cpu(&mut self) -> Result<FloatMessage> {
        let mut sys = self.sys.as_mut().unwrap();
        let value = sys.global_cpu_usage();
        sys.refresh_cpu_usage();
        Ok(FloatMessage {
            value,
        })
    }

    fn get_ram(&mut self) -> Result<FloatMessage> {
        let mut sys = self.sys.as_mut().unwrap();
        sys.refresh_memory();
        let value = 1.0 - (sys.used_memory() as f32 / sys.total_memory() as f32);
        Ok(FloatMessage {
            value,
        })
    }
}