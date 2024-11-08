use std::fmt::Debug;
use std::path::PathBuf;
use prost::Message;
use std::sync::Arc;
use std::time::UNIX_EPOCH;
use ahash::{AHashMap, AHashSet, HashMap, HashSet};
use async_trait::async_trait;
use crate::{async_func_notype, func_end, func_notype, func_typeno};
use crate::common::global_data::GlobalData;
use crate::service::service::Service;
use anyhow::{anyhow, Result};
use log::error;
use reqwest_dav::{Auth, Client, ClientBuilder, Depth};
use reqwest_dav::list_cmd::ListEntity;
use rinf::debug_print;
use serde::{Deserialize, Serialize};
use tokio::fs::metadata;
use crate::common::utils::get_machine_id;
use crate::common::WEBDAV_SYNC_DIR;
use crate::messages::common::{BoolMessage, StringMessage, VecStringMessage};
use crate::messages::syncfile::{FileMsg, FileStatusEnum, ListFileMsg};

#[derive(Debug, Serialize, Deserialize)]
struct AccountInfo {
    user: String,
    passwd: String,
    url: String,
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct LocalRemoteFileMappingDO {
    // 存储文件路径
    // k: 远端路径 v: 本地路径
    files: HashMap<String, String>,
}

/// 远端文件属性
#[derive(Debug, Default, Serialize, Deserialize)]
struct RemoteFileMedata {
    // 远端最新一次修改时间 ms
    last_time: u128,
    // 远端所有文件路径+最新修改时间
    files: AHashMap<String, u128>,
}

/// 本地文件属性
type LocalFileMetadata = RemoteFileMedata;

/// 文件同步服务
pub struct SyncFileService {
    // 全局数据存储
    global_data: Arc<GlobalData>,
    // 账号信息
    account_info: Option<AccountInfo>,
    // 本地文件与远端文件地址映射关系
    file_sync: LocalRemoteFileMappingDO,
}

const NAME: &str = "SyncFileService";
const ACCOUNT_CACHE: &str = "accountCache";
const SYNC_FILE_PREFIX: &str = "syncFilePrefix";

#[async_trait]
impl Service for SyncFileService {
    fn get_service_name(&self) -> &'static str {
        NAME
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_notype!(self, func, has_account);

        func_end!(func)
    }
}

impl SyncFileService {
    pub fn new(global_data: Arc<GlobalData>) -> Result<Self> {
        let account = global_data.get_data(ACCOUNT_CACHE);
        let file_sync = global_data.get_data(&format!("{}-{}", SYNC_FILE_PREFIX, get_machine_id()?))
            .unwrap_or_default();
        let r = Self {
            global_data,
            file_sync,
            account_info: account,
        };

        Ok(r)
    }
}

impl SyncFileService {
    /// 测试帐号是否可用
    async fn has_account(&self) -> Result<BoolMessage> {
        match &self.account_info {
            None => {
                Ok(BoolMessage { value: false })
            }
            Some(account) => {
                Ok(BoolMessage {
                    value: Self::connect(account).await.is_ok()
                })
            }
        }
    }


    /// 同步文件列表
    async fn list_files(&mut self) -> Result<ListFileMsg> {
        let remote_files = Self::get_remote_dirs(self.account_info.as_ref().ok_or(anyhow!("无账号信息，请先登录注册"))?).await?;
        let real_remote: AHashSet<&String> = remote_files.keys().collect();
        let local_remote: AHashSet<&String> = self.file_sync.files.keys().collect();
        let mut result: Vec<FileMsg> = Vec::new();

        // 本地有，远端没有，表示 远端数据已删除 需要提示删除本地
        for file in local_remote.difference(&real_remote) {
            result.push(FileMsg {
                local_dir: self.file_sync.files.get(file).unwrap().clone(),
                remote_dir: "".to_string(),
                id: "".to_string(),
                status: 0,
                new: 0,
                del: 0,
                old: 0,
            });
        }

        // 远端有，本地没有，表示其它设备新上传的文件夹 需要提示映射本地文件夹
        for file in real_remote.difference(&local_remote) {
            result.push(FileMsg {
                local_dir: "".to_string(),
                remote_dir: file.to_string(),
                id: "".to_string(),
                status: 0,
                new: 0,
                del: 0,
                old: 0,
            });
        }

        // 双方都有，则需要同步操作
        for file in local_remote.union(&real_remote) {
            let local_path = self.file_sync.files.get(file).unwrap();
            let l_metadata = Self::get_newest_file(local_path).await?;
            let r_metadata = remote_files.get(file).unwrap();
            Self::diff_local_remote_file(&l_metadata, r_metadata);
           
        }
        todo!()
        // Ok(())
    }
}


impl SyncFileService {
    /// 连接webdav服务
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

    /// 获取远端服务的所有文件夹绝对路由（String）及每一项的文件属性
    async fn get_remote_dirs(account_info: &AccountInfo) -> Result<AHashMap<String, RemoteFileMedata>> {
        let mut remote_files = AHashMap::new();
        let client = Self::connect(account_info).await?;
        let files = client.list(WEBDAV_SYNC_DIR, Depth::Number(1)).await?;
        for file in files.iter().skip(1) {
            if let ListEntity::Folder(dir) = file {
                if let Some(dir) = dir.href.splitn(2, WEBDAV_SYNC_DIR).skip(1).next() {
                    let metadata = Self::get_remote_dir_metadatas(&client, dir).await
                        .or_else(|x| Err(anyhow!("无法获取远端文件夹属性文件{}修改时间 {}", dir, x)))?;
                    remote_files.insert(dir.to_string(), metadata);
                }
            }
        }

        Ok(remote_files)
    }

    /// 获取远端目录文件属性
    async fn get_remote_dir_metadatas(client: &Client, dir: &str) -> Result<RemoteFileMedata> {
        let dir = format!("{}{}/.last_time", WEBDAV_SYNC_DIR, dir);
        let rsp = client.get(&dir).await?;
        let rsp = rsp.text().await?;
        Ok(serde_json::from_str(&rsp)?)
    }

    /// 获取本地目录下 所有文件属性+最新的文件修改时间
    async fn get_newest_file(dir: &str) -> Result<LocalFileMetadata> {
        let mut files = AHashMap::new();
        let mut max_time = 0;
        for entry in walkdir::WalkDir::new(dir) {
            if entry.is_err() {
                continue;
            }
            let entry = entry.unwrap();
            if entry.path().is_dir() || entry.path().is_symlink() {
                continue;
            }

            let metadata = metadata(entry.path()).await?;
            let max = metadata.modified()?.duration_since(UNIX_EPOCH)?.as_millis();
            files.insert(entry.path().to_str().unwrap().to_string(), max);
            max_time = max.max(max_time);
        }

        Ok(LocalFileMetadata {
            last_time: max_time,
            files,
        })
    }
    
    /// 对比本地与远端文件差异
    fn diff_local_remote_file(l_metadata: &LocalFileMetadata, r_metadata: &RemoteFileMedata) {
        if l_metadata.last_time > r_metadata.last_time {
            // 本地比远端新

        } else if l_metadata.last_time < r_metadata.last_time {
            // 远端比本地新
        } else {
            // 一样新 无需同步
        }
    }
}

impl Drop for SyncFileService {
    fn drop(&mut self) {
        if let Ok(id) = get_machine_id() {
            if let Err(e) = self.global_data.set_data(format!("{}-{}", SYNC_FILE_PREFIX, id), &self.file_sync) {
                error!("{}", e);
            }
        }

        if let Err(e) = self.global_data.set_data(ACCOUNT_CACHE.to_string(), &self.account_info) {
            error!("{}", e);
        }
    }
}

mod test {
    use std::sync::Arc;
    use crate::common::global_data::GlobalData;
    use crate::service::syncfile::{AccountInfo, SyncFileService};

    #[tokio::test]
    async fn webdav() {
        // let gd = Arc::new(GlobalData::new().unwrap());
        // let sync_file = SyncFile::new(gd);
        let account = AccountInfo {
            url: "https://dav.jianguoyun.com/dav/".to_string(),
            user: "1261805497@qq.com".to_string(),
            passwd: "a22xnw294yj5h9d3".to_string(),
        };
        // SyncFile::connect(&account).await.unwrap();
        let map = SyncFileService::get_remote_dirs(&account).await.unwrap();
        eprintln!("{:?}", map);
        let l_metadata = SyncFileService::get_newest_file(r#"C:\Users\12618\Desktop\tmp\IP解析"#).await.unwrap();
        eprintln!("{:?}", l_metadata);
    }
}