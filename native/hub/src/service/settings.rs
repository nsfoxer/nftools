use crate::messages::syncfile::WebDavConfig;
use std::sync::Arc;
use crate::common::global_data::{DataPersist, GlobalData};
use crate::{async_func_typeno, func_end, func_notype};
use crate::service::service::Service;
use anyhow::Result;
use reqwest_dav::{Auth, ClientBuilder, Depth};
use prost::Message;
use serde::{Deserialize, Serialize};
use crate::r#do::webdav_account_do::WebDavAccountDO;

struct GlobalSettings {
    global_data: Arc<GlobalData>,
    web_dav_account_do: WebDavAccountDO,
}

impl GlobalSettings {
    fn new(global_data: Arc<GlobalData>) -> Self {
        Self {
            web_dav_account_do: WebDavAccountDO::get_data(&global_data).unwrap_or(Default::default()),
            global_data,
        }
    }
}

const NAME: &str = "GlobalSettings";

#[async_trait::async_trait]
impl Service for GlobalSettings {
    fn get_service_name(&self) -> &'static str {
        NAME
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_typeno!(self, func, req_data, set_webdav_account, WebDavConfig);
        func_notype!(self, func, get_webav_account);
        
        func_end!(func)
    }
}

impl GlobalSettings {
    async fn set_webdav_account(&mut self, dav_config: WebDavConfig) -> Result<()> {
        let client = ClientBuilder::new()
            .set_host(dav_config.url.clone())
            .set_auth(Auth::Basic(dav_config.account.clone(), dav_config.passwd.clone()))
            .build()?;
        let _ = client.list("/", Depth::Number(0)).await?;

        self.web_dav_account_do.url = dav_config.url;
        self.web_dav_account_do.account = dav_config.account;
        self.web_dav_account_do.passwd = dav_config.passwd;

        self.web_dav_account_do.set_data(&self.global_data)
    }
    
    fn get_webav_account(&self) -> Result<WebDavConfig> {
        Ok(WebDavConfig {
            url: self.web_dav_account_do.url.clone(),
            account: self.web_dav_account_do.account.clone(),
            passwd: self.web_dav_account_do.passwd.clone(),
        })
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

