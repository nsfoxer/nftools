use crate::common::utils::{get_cache_dir, version};
use crate::messages::common::StringMessage;
use crate::service::service::{Service, ServiceName};
use std::time::Duration;

use crate::{async_func_nono, async_func_notype, func_end, func_notype};
use anyhow::Result;
use futures_util::StreamExt;
use prost::Message;
use serde::Deserialize;
use tokio::fs::File;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use tokio::time::sleep;

#[derive(Debug, Deserialize)]
struct VersionInfo {
    // 最新版本
    version: String,
    // 最新包下载地址
    package_server: String,
    // 当前版本的更新记录
    record: String,
}

/// 关于 服务
pub struct AboutService {
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
        async_func_notype!(self, func, check_updates, record);
        func_notype!(self, func, version);
        async_func_nono!(self, func, install_newest);
        func_end!(func)
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

    /// 获取更新信息
    async fn record(&mut self) -> Result<StringMessage> {
        self.get_version_info(false).await?;
        let version_info = self.version_info.as_ref().unwrap();
        
        Ok(StringMessage { value: version_info.record.clone() })
    }

    /// 下载和安装最新版
    async fn install_newest(&mut self) -> Result<()> {
        self.get_version_info(false).await?;
        if !cfg!(target_os = "windows") {
            return Err(anyhow::anyhow!("目前仅支持windows安装"));
        }

        // 下载
        let mut path = get_cache_dir()?;
        path.push("installed-nftools.exe");
        let rsp = reqwest::get(&self.version_info.as_ref().unwrap().package_server).await?;
        if !rsp.status().is_success() {
            return Err(anyhow::anyhow!(
                "下载文件失败。响应码:{}",
                rsp.status().as_u16()
            ));
        }
        let mut file = File::create(&path).await?;
        let mut bytes_stream = rsp.bytes_stream();
        while let Some(content) = bytes_stream.next().await {
            file.write_all(&content?).await?;
        }
        drop(file);

        // 安装
        let _ = Command::new(&path).spawn()?;
        sleep(Duration::from_secs(3)).await;
        // kill me
        std::process::exit(0);
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

mod test{
    use futures_util::StreamExt;
    use tokio::fs::File;
    use tokio::io::AsyncWriteExt;
    use crate::common::utils::get_cache_dir;

    #[tokio::test]
    async fn download() {
        let mut path = get_cache_dir().unwrap();
        path.push("installed-nftools.exe");
        let client = reqwest::Client::builder().danger_accept_invalid_certs(true).build().unwrap();
        let rsp = client.get("https://36.50.226.35:27572/nftools/win/nftools.exe").send().await.unwrap();
        if !rsp.status().is_success() {
            panic!("{:?}", rsp.status().as_u16());
        }
        let mut file = File::create(&path).await.unwrap();
        let mut bytes_stream = rsp.bytes_stream();
        while let Some(content) = bytes_stream.next().await {
            file.write_all(&content.unwrap()).await.unwrap();
        }
    }
}
