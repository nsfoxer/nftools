use async_trait::async_trait;
use crate::{async_func_notype, func_end, func_notype};
use crate::messages::display::DisplaySupport;
use crate::service::service::{ImmService, Service};
use anyhow::Result;
use prost::Message;

pub struct DisplayInfo {
}

#[async_trait]
impl ImmService for DisplayInfo {
    fn get_service_name(&self) -> &'static str {
        "display_info"
    }

    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_notype!(self, func, support);
        func_end!(func)
    }
}

impl DisplayInfo {
    async fn support(&self) -> Result<DisplaySupport>  {
        let r = DisplaySupport {
            support: true
        };
        Ok(r)
    }
}