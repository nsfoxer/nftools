use crate::messages::syncfile::WebDavConfig;
use std::sync::Arc;
use crate::common::global_data::GlobalData;
use crate::{async_func_typeno, func_end};
use crate::service::service::Service;
use anyhow::Result;
use reqwest_dav::{Auth, ClientBuilder, Depth};
use prost::Message;
use serde::{Deserialize, Serialize};

struct GlobalSettings {
    global_data: Arc<GlobalData>,
    data: Data,
}

impl GlobalSettings {
    fn new(global_data: Arc<GlobalData>) -> Self {
        let data =  global_data.get_data(NAME).unwrap_or(Data::default());
        Self { global_data, data }
    }
}

const NAME: &str = "GlobalSettings";
pub const WEBDAV_ACCOUNT: &str = "GlobalSettings:WebDavAccount";

#[async_trait::async_trait]
impl Service for GlobalSettings {
    fn get_service_name(&self) -> &'static str {
        NAME
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_typeno!(self, func, req_data, set_webdav_account, WebDavConfig);
        func_end!(func)
    }
}

impl GlobalSettings {
    async fn set_webdav_account(&mut self, dav_config: WebDavConfig) -> Result<()>{
        let client = ClientBuilder::new()
            .set_host(dav_config.url.clone())
            .set_auth(Auth::Basic(dav_config.account.clone(), dav_config.passwd.clone()))
            .build()?;
        let _ = client.list("/", Depth::Number(0)).await?;
        
        
        
        self.data.web_dav_config = (dav_config.url, dav_config.account, dav_config.passwd);
        Ok(())
    }
    
    
}
impl Drop for GlobalSettings {
    fn drop(&mut self) {
        self.global_data.set_data(NAME.to_string(), &self.data).unwrap_or_else(|e| {
           eprintln!("Failed to set global data: {}", e); 
        });
    }
}



mod test {
    use std::sync::Arc;
    use crate::common::global_data::GlobalData;
    use crate::messages::syncfile::WebDavConfig;
    use crate::service::settings::GlobalSettings;

    #[tokio::test]
    async fn test() {
        let mut s = GlobalSettings::new(Arc::new(GlobalData::new().unwrap()));
        s.set_webdav_account(WebDavConfig {
            url: "https://dav.jianguoyun.com/dav".to_string(),
            account: "1261805497@qq.com".to_string(),
            passwd: "a2arv4q9zzav8jwq".to_string(),
        }).await.unwrap();
    }
}

