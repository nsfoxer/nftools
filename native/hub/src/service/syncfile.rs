use prost::Message;
use std::sync::Arc;
use ahash::HashSet;
use async_trait::async_trait;
use crate::{func_end, func_notype, func_typeno};
use crate::common::global_data::{DataPersist, GlobalData};
use crate::service::service::Service;
use anyhow::{anyhow, Result};
use reqwest_dav::{Auth, Client, ClientBuilder};
use rinf::debug_print;
use crate::messages::common::{StringMessage, VecStringMessage};
use crate::r#do::webdav_account_do::WebDavAccountDO;

pub struct SyncFile {
    global_data: Arc<GlobalData>,
    files: HashSet<String>,
    client: Option<Client>,
}

const NAME: &str = "SyncFile";

#[async_trait]
impl Service for SyncFile {
    fn get_service_name(&self) -> &'static str {
        NAME
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, add_file, StringMessage, del_file, StringMessage);
        func_notype!(self, func, get_files);
        
        func_end!(func)
    }
}

impl SyncFile {
    pub fn new(global_data: Arc<GlobalData>) -> Self {
        let files = global_data.get_data(NAME).unwrap_or_default();
        Self {
            global_data,
            files,
            client: None,
        }
    }
}

impl SyncFile {
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
        
        
        Ok(())
    }
    
}

impl SyncFile {
    async fn init_dav(&mut self) -> Result<()> {
        let dav = WebDavAccountDO::get_data(&self.global_data).ok_or_else(|| anyhow!("账户未配置，请先在设置中配置账户"))?;
        let client = ClientBuilder::new()
            .set_host(dav.url)
            .set_auth(Auth::Basic(dav.account, dav.passwd))
            .build()?;
        self.client = Some(client);
        Ok(())
    }
}

impl Drop for SyncFile {
    fn drop(&mut self) {
        if let Err(e) = self.global_data.set_data(NAME.to_string(), &self.files) {
            debug_print!("{}", e);
        }
    }
}