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
struct FileSyncLocalDO {
    // 存储文件路径
    // k: 远端路径 v: 本地路径
    files: HashMap<String, String>
}

pub struct SyncFile {
    global_data: Arc<GlobalData>,
    files: HashSet<String>,
    account_info: Option<AccountInfo>,
    file_sync: FileSyncLocalDO,
}

const NAME: &str = "SyncFileService";
const ACCOUNT_CACHE: &str = "accountCache";
const SYNC_FILE_PREFIX: &str = "syncFilePrefix";

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
    pub fn new(global_data: Arc<GlobalData>) -> Result<Self> {
        let files = global_data.get_data(NAME).unwrap_or_default();
        let account = global_data.get_data(ACCOUNT_CACHE);
        let file_sync = global_data.get_data(&format!("{}-{}", SYNC_FILE_PREFIX, get_machine_id()?))
            .unwrap_or_default();
        let r = Self {
            global_data,
            files,
            file_sync,
            account_info: account,
        };

        Ok(r)
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
        let remote_files = Self::get_remote_dirs(self.account_info.as_ref().ok_or(anyhow!("无账号信息，请先登录注册"))?).await?;
        let real_remote: AHashSet<&String> = remote_files.keys().collect();
        let local_remote: AHashSet<&String> = self.file_sync.files.keys().collect();
        let mut result: Vec<FileMsg> = Vec::new();

        // 本地有，远端没有，表示 远端数据已删除 需要提示删除本地
        for file in local_remote.difference(&real_remote) {
            result.push(FileMsg{
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
            result.push(FileMsg{
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
            let local_newest = Self::get_newest_file(local_path).await?;
            let remote_newest = remote_files.get(file).unwrap();
            if local_newest > *remote_newest {

            } else if local_newest < *remote_newest {

            } else {
                result.push(FileMsg{
                    local_dir: "".to_string(),
                    remote_dir: "".to_string(),
                    id: "".to_string(),
                    status: i32::from(FileStatusEnum::Synced),
                    new: 0,
                    del: 0,
                    old: 0,
                });
            }

        }



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

    // 获取远端服务的所有文件夹绝对路由（String）及每一项的最新修改时间(u64 ms)
    async fn get_remote_dirs(account_info: &AccountInfo) -> Result<AHashMap<String, u128>> {
        let mut remote_files = AHashMap::new();
        let client = Self::connect(account_info).await?;
        let files = client.list(WEBDAV_SYNC_DIR, Depth::Number(1)).await?;
        for file in files.iter().skip(1) {
            if let ListEntity::Folder(dir) = file {
                if let Some(dir) = dir.href.splitn(2, WEBDAV_SYNC_DIR).skip(1).next() {
                    let last_time = Self::get_remote_dir_last_time(&client, dir).await
                        .or_else(|x| Err(anyhow!("无法获取远端文件夹{}的修改时间{}", dir, x)))?;
                    remote_files.insert(dir.to_string(), last_time);
                }
            }
        }

        Ok(remote_files)
    }

    /// 获取远端目录最后修改时间
    async fn get_remote_dir_last_time(client: &Client, dir: &str) -> Result<u128> {
        let dir = format!("{}{}/.last_time", WEBDAV_SYNC_DIR, dir);
        let rsp = client.get(&dir).await?;
        let rsp = rsp.text().await?;
        Ok(rsp.parse::<u128>()?)
    }

    /// 获取目录下最新的文件修改时间
    async fn get_newest_file(dir: &str) -> Result<u128> {
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
            max_time = max.max(max_time);
        }

        Ok(max_time)
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
        // SyncFile::connect(&account).await.unwrap();
        SyncFile::get_remote_dirs(&account).await.unwrap();
    }
}