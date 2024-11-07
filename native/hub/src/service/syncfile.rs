use prost::Message;
use std::sync::Arc;
use ahash::HashSet;
use async_trait::async_trait;
use crate::{async_func_notype, func_end, func_notype, func_typeno};
use crate::common::global_data::GlobalData;
use crate::service::service::Service;
use anyhow::{anyhow, Result};
use reqwest_dav::{Auth, Client, ClientBuilder, Depth};
use rinf::debug_print;
use serde::{Deserialize, Serialize};
use crate::common::WEBDAV_SYNC_DIR;
use crate::messages::common::{BoolMessage, StringMessage, VecStringMessage};
use crate::messages::syncfile::ListFileMsg;

#[derive(Debug, Serialize, Deserialize)]
struct AccountInfo {
    user: String,
    passwd: String,
    url: String,
}

pub struct SyncFile {
    global_data: Arc<GlobalData>,
    files: HashSet<String>,
    account_info: Option<AccountInfo>,
}

const NAME: &str = "SyncFileService";
const ACCOUNT_CACHE: &str = "accountCache";

#[async_trait]
impl Service for SyncFile {
    fn get_service_name(&self) -> &'static str {
        NAME
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, add_file, StringMessage, del_file, StringMessage);
        func_notype!(self, func, get_files);
        
        async_func_notype!(self, func, has_account);
        
        func_end!(func)
    }
}

impl SyncFile {
    pub fn new(global_data: Arc<GlobalData>) -> Self {
        let files = global_data.get_data(NAME).unwrap_or_default();
        let account = global_data.get_data(ACCOUNT_CACHE);
        Self {
            global_data,
            files,
            account_info: account,
        }
    }
}

impl SyncFile {
    /// 测试帐号是否可用
    async fn has_account(&self) -> Result<BoolMessage> {
        match &self.account_info {
            None => {
                Ok(BoolMessage{value: false})
            },
            Some(account) => {
                Ok(BoolMessage{
                    value: Self::connect(account).await.is_ok()
                })
            }
        }
    }
    
    
    /// 同步文件列表
    async fn list_files(&mut self) -> Result<ListFileMsg> {
        
        Ok(())
    }
    
    fn add_file(&mut self, file: StringMessage) -> Result<()> {
        self.files.insert(file.value);
        Ok(())
    }

    fn del_file(&mut self, file: StringMessage) -> Result<()> {
        self.files.remove(&file.value);
        Ok(())
    }

    fn get_files(&mut self) -> Result<VecStringMessage> {
        Ok(VecStringMessage { values: self.files.iter().map(|x| x.clone()).collect() })
    }
    
    async fn sync_file(&self) -> Result<()> {
        unimplemented!()
    }
    
    async fn file_status(&mut self) -> Result<()> {
        self.init_dav().await?;
        // 1. 查询远端
        
        Ok(())
    }
    
}

impl SyncFile {
    async fn init_dav(&mut self) -> Result<()> {

        Ok(())
    }

    async fn connect(account: &AccountInfo) -> Result<Client> {
        let client = ClientBuilder::new()
            .set_host(account.url.to_string())
            .set_auth(Auth::Basic(account.user.to_owned(), account.passwd.to_owned()))
            .build()?;
        let _ = client.list("/", Depth::Number(0)).await?;

        if client.list(WEBDAV_SYNC_DIR, Depth::Number(0)).await.is_err() {
            client.mkcol(WEBDAV_SYNC_DIR).await?;
        }
        Ok(client)
    }
}

impl Drop for SyncFile {
    fn drop(&mut self) {
        if let Err(e) = self.global_data.set_data(NAME.to_string(), &self.files) {
            debug_print!("{}", e);
        }
    }
}

mod test {
    use std::sync::Arc;
    use crate::common::global_data::GlobalData;
    use crate::service::syncfile::{AccountInfo, SyncFile};

    #[tokio::test]
    async fn webdav() {
        // let gd = Arc::new(GlobalData::new().unwrap());
        // let sync_file = SyncFile::new(gd);
        let account = AccountInfo {
          url: "https://dav.jianguoyun.com/dav/".to_string(),
            user: "1261805497@qq.com".to_string(),
            passwd: "a22xnw294yj5h9d3".to_string(),
        };
        SyncFile::connect(&account).await.unwrap();
    }
}