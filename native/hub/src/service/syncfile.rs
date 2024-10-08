use std::sync::Arc;
use async_trait::async_trait;
use serde::{Deserialize, Serialize, Serializer};
use crate::func_end;
use crate::service::global_settings::GlobalData;
use crate::service::service::Service;
use anyhow::Result;
use crate::messages::common::EmptyMessage;

pub struct SyncFile {
    global_data: Arc<GlobalData>,
    files: Vec<String>,
}

const NAME: &str = "SyncFile"; 

#[async_trait]
impl Service for SyncFile {
    fn get_service_name(&self) -> &'static str {
        NAME
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_end!(func)
    }
}

#[derive(Serialize, Deserialize)]
struct A{
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
    fn add_file(&mut self, file: String) -> Result<EmptyMessage> {
        self.files.push(file);
        Ok(EmptyMessage{})
    }
    
    fn get_files(&mut self, file: String) -> Result<> {
        self.files
    }
}