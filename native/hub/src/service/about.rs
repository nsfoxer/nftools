use crate::common::utils::version;
use crate::messages::common::StringMessage;
use crate::service::service::{Service, ServiceName};
use ahash::AHashMap;

use anyhow::Result;
use serde::Deserialize;
use crate::messages::about::{VersionHistoryListMsg, VersionHistoryMsg};

#[derive(Debug, Deserialize)]
struct VersionInfo {
    // 最新版本
    version: String,
    // 最新包下载地址
    package_server: String,
    // 历史记录
    history: Vec<VersionHistory>,
}
#[derive(Debug, Deserialize)]
struct VersionHistory {
    version: String,
    record: String,
}

/// 关于 服务
struct AboutService {
    version_info: Option<VersionInfo>,
}

const NAME: &str = "AboutService";
const URL: &str = "https://nsfoxer-oss.oss-cn-beijing.aliyuncs.com/nftools/server.json";

impl ServiceName for AboutService {
    fn get_service_name(&self) -> &'static str {
        NAME
    }
}

#[async_trait::async_trait]
impl Service for AboutService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        todo!()
    }
}

impl AboutService {
    /// 获取当前版本号
    fn version(&self) -> Result<StringMessage> {
        Ok(StringMessage { value: version() })
    }

    /// 检查新版本
    async fn check_updates(&mut self) -> Result<StringMessage> {
        self.get_version_info(true).await?;
        let version = self.version_info.as_ref().unwrap().version.clone();
        Ok(StringMessage { value: version })
    }

    async fn get_history(&mut self) -> Result<VersionHistoryListMsg> {
        self.get_version_info(false).await?;
        let version_info = self.version_info.as_ref().unwrap();
        let result = version_info.history.iter().map(|x| VersionHistoryMsg{
            version: x.version.clone(),
            record: x.record.clone(),
        }).collect();
        Ok(VersionHistoryListMsg{
            versions: result
        })
    }
}

impl AboutService {
    /// new
    pub fn new() -> AboutService {
        Self { version_info: None }
    }

    /// 获取最新版version info
    async fn get_version_info(&mut self, force_check: bool) -> Result<()> {
        if force_check || self.version_info.is_none() {
            let r = reqwest::get(URL).await?.json().await?;
            self.version_info = Some(r);
        }
        Ok(())
    }
}
