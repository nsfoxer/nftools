use prost::Message;
use std::sync::Arc;
use ahash::HashSet;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use crate::{func_end, func_notype, func_typeno};
use crate::common::global_data::GlobalData;
use crate::service::service::Service;
use anyhow::Result;
use rinf::debug_print;
use crate::messages::common::{StringMessage, VecStringMessage};

pub struct SyncFile {
    global_data: Arc<GlobalData>,
    files: HashSet<String>,
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

#[derive(Serialize, Deserialize)]
struct A {
    f: String,
}

impl SyncFile {
    pub fn new(global_data: Arc<GlobalData>) -> Self {
        let files = global_data.get_data(NAME).unwrap_or_default();
        Self {
            global_data,
            files,
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
    
}

impl Drop for SyncFile {
    fn drop(&mut self) {
        if let Err(e) = self.global_data.set_data(NAME.to_string(), &self.files) {
            debug_print!("{}", e);
        }
    }
}