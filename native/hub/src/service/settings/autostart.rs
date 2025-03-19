use crate::{common, func_end, func_notype, func_typeno};
use crate::common::utils;
use crate::messages::common::BoolMessage;
use crate::service::service::{ImmService};
use anyhow::Result;
use auto_launch::AutoLaunch;
use prost::Message;

/// 开机自启动服务
pub struct AutoStartService {
    auto_launch: AutoLaunch,
}

#[async_trait::async_trait]
impl ImmService for AutoStartService {
    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_notype!(self, func, get_autostart);
        func_typeno!(self, func, req_data, set_autostart, BoolMessage);
        func_end!(func)
    }
}

impl AutoStartService {
    pub fn new() -> Result<Self> {
        let auto = AutoLaunch::new(
            common::APP_NAME,
            utils::location_path()?
                .to_str()
                .ok_or(anyhow::anyhow!("无法转换字符"))?,
            &[] as &[&str],
        );
        Ok(Self { auto_launch: auto })
    }

    /// 获取是否已启用开机自启动
    fn get_autostart(&self) -> Result<BoolMessage> {
        let r = self.auto_launch.is_enabled()?;
        Ok(BoolMessage{value: r})
    }

    /// 启用或禁用开机自启动
    fn set_autostart(&self, value: BoolMessage) -> Result<()> {
        if value.value {
            self.auto_launch.enable()?;
        } else {
            self.auto_launch.disable()?;
        }
        Ok(())
    }
}
