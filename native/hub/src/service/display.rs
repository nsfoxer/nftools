use async_trait::async_trait;
use crate::func_end;
use crate::service::service::Service;

pub struct DisplayInfo {

}

#[async_trait]
impl Service for DisplayInfo {
    fn get_service_name(&self) -> &'static str {
        "display_info"
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> anyhow::Result<Option<Vec<u8>>> {
        
        func_end!(func)
    }
}