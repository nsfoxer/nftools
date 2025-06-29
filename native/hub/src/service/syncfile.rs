use crate::common::global_data::GlobalData;
use crate::common::utils::{get_machine_id, sha256};
use crate::common::WEBDAV_SYNC_DIR;
use crate::messages::common::{BoolMsg, StringMsg, UintFiveMsg};
use crate::messages::syncfile::{AddLocalForRemoteMsg, AddSyncDirMsg, FileMsg, FileStatusEnumMsg, ListFileMsg, SyncFileDetailMsg, WebDavConfigMsg};
use crate::service::service::Service;
use crate::{
    async_func_notype, async_func_typeno, async_func_typetype, func_end, func_notype, func_typeno,
};
use ahash::{AHashMap, AHashSet};
use anyhow::{anyhow, Result};
use async_trait::async_trait;
use filetime::FileTime;
use reqwest_dav::list_cmd::ListEntity;
use reqwest_dav::re_exports::reqwest::Body;
use reqwest_dav::{Auth, Client, ClientBuilder, Depth};
use serde::{Deserialize, Serialize};
use std::fmt::Debug;
use std::ops::Add;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::fs::{create_dir_all, metadata, File};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

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
    files: AHashMap<String, String>,
}

/// 远端文件属性
#[derive(Debug, Default, Serialize, Deserialize)]
struct RemoteFileMedata {
    // 最初文件地址(方便使用)
    tag: String,
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
    global_data: GlobalData,
    // 账号信息
    account_info: Option<AccountInfo>,
    // 本地文件与远端文件地址映射关系
    file_sync: LocalRemoteFileMappingDO,
    // client
    client: Option<Client>,
    // timer
    timer: Option<u32>,
}

const NAME: &str = "SyncFileService";
const TIMER_CACHE: &str = "timerCache";
const ACCOUNT_CACHE: &str = "accountCache";
const SYNC_FILE_PREFIX: &str = "syncFilePrefix";
const METADATA_FILE: &str = ".sync_file.db";

#[async_trait]
impl Service for SyncFileService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_notype!(self, func, has_account, list_dirs, get_timer);
        async_func_typetype!(
            self,
            func,
            req_data,
            sync_dir,
            StringMsg,
            set_account,
            WebDavConfigMsg,
            add_sync_dir,
            AddSyncDirMsg,
            add_local_file,
            AddLocal4RemoteMsg
        );

        async_func_typeno!(self, func, req_data, del_remote_dir, StringMsg, set_timer, Uint32Msg);

        func_typeno!(self, func, req_data, del_local_dir, StringMsg);
        func_notype!(self, func, get_account);

        func_end!(func)
    }

    /// 关闭服务时保存数据
    async fn close(&mut self) -> Result<()> {
        self.global_data.set_data(ACCOUNT_CACHE.to_string(), &self.account_info).await?;
        self.global_data.set_data(format!("{}-{}", SYNC_FILE_PREFIX, get_machine_id()?), &self.file_sync).await?;
        self.global_data.set_data(TIMER_CACHE.to_string(), &self.timer).await?;
        Ok(())
    }
}

impl SyncFileService {
    pub async fn new(global_data: GlobalData) -> Result<Self> {
        let account = global_data.get_data(ACCOUNT_CACHE.to_string()).await;
        let file_sync = global_data
            .get_data(format!("{}-{}", SYNC_FILE_PREFIX, get_machine_id()?))
            .await
            .unwrap_or_default();
        let r = Self {
            file_sync,
            account_info: account,
            client: None,
            timer: global_data.get_data(TIMER_CACHE.to_string()).await,
            global_data,
        };

        Ok(r)
    }
}

impl SyncFileService {
    /// 保存定时器时间
    async fn set_timer(&mut self, timer: UintFiveMsg) -> Result<()> {
        self.timer = Some(timer.value);
        Ok(())
    }
    
    /// 获取定时器时间
    async fn get_timer(&self) -> Result<UintFiveMsg> {
        Ok(UintFiveMsg {
            value: self.timer.unwrap_or(0),
        })
    }

    /// 测试帐号是否可用
    async fn has_account(&mut self) -> Result<BoolMsg> {
        match &self.account_info {
            None => Ok(BoolMsg { value: false }),
            Some(account) => {
                let client = Self::connect(account).await?;
                self.client = Some(client);
                Ok(BoolMsg { value: true })
            }
        }
        
    }

    /// 获取账户信息
    fn get_account(&self) -> Result<WebDavConfigMsg> {
        let account = self
            .account_info
            .as_ref()
            .ok_or_else(|| anyhow!("无账户信息"))?;
        Ok(WebDavConfigMsg {
            url: account.url.clone(),
            account: account.user.clone(),
            passwd: account.passwd.clone(),
        })
    }

    /// 设置账户信息
    async fn set_account(&mut self, account: WebDavConfigMsg) -> Result<BoolMsg> {
        let account = AccountInfo {
            user: account.account,
            passwd: account.passwd,
            url: account.url,
        };
        self.account_info = Some(account);
        self.has_account().await
    }

    /// 同步文件列表信息
    async fn list_dirs(&mut self) -> Result<ListFileMsg> {
        let remote_files = Self::get_remote_dirs(
            self.client
                .as_ref()
                .ok_or_else(|| anyhow!("无账户信息，请登录"))?,
        )
        .await?;
        let real_remote: AHashSet<&String> = remote_files.keys().collect();
        let local_remote: AHashSet<&String> = self.file_sync.files.keys().collect();
        let mut result: Vec<FileMsg> = Vec::new();

        // 本地有，远端没有，表示 远端数据已删除 需要提示删除本地
        for file in local_remote.difference(&real_remote) {
            result.push(FileMsg {
                local_dir: self.file_sync.files.get(*file).unwrap().clone(),
                remote_dir: "".to_string(),
                status: FileStatusEnumMsg::UPLOAD,
                add: 0,
                del: 0,
                modify: 0,
                tag: "".to_string(),
            });
        }

        // 远端有，本地没有，表示其它设备新上传的文件夹 需要提示映射本地文件夹
        for file in real_remote.difference(&local_remote) {
            result.push(FileMsg {
                local_dir: "".to_string(),
                remote_dir: file.to_string(),
                status: FileStatusEnumMsg::UPLOAD,
                add: 0,
                del: 0,
                modify: 0,
                tag: remote_files.get(*file).unwrap().tag.clone(),
            });
        }

        // 双方都有，则需要同步操作
        for file in local_remote.intersection(&real_remote) {
            let local_path = self.file_sync.files.get(*file).unwrap();
            let l_metadata = Self::get_newest_file(local_path).await?;
            let r_metadata = remote_files.get(*file).unwrap();
            let diff_result = Self::diff_local_remote_file(&l_metadata, r_metadata);
            result.push(FileMsg {
                local_dir: self.file_sync.files.get(*file).unwrap().clone(),
                remote_dir: file.to_string(),
                status: diff_result.0.into(),
                add: diff_result.1.len() as u32,
                del: diff_result.2.len() as u32,
                modify: diff_result.3.len() as u32,
                tag: remote_files.get(*file).unwrap().tag.clone(),
            });
        }
        Ok(ListFileMsg { files: result })
    }

    /// 同步一个文件夹
    async fn sync_dir(&mut self, remote_dir: StringMsg) -> Result<SyncFileDetailMsg> {
        // 获取本地文件属性
        let local_dir = self
            .file_sync
            .files
            .get(&remote_dir.value)
            .ok_or(anyhow!("远端路径不存在"))?;
        let l_metadata = Self::get_newest_file(local_dir).await?;
        // 获取远端文件属性
        let client = self
            .client
            .as_ref()
            .ok_or_else(|| anyhow!("无登录信息，请先登录"))?;
        let mut remote_metadata = Self::get_remote_dir_metadatas(client, &remote_dir.value).await?;
        // 对比文件差异
        let (status, mut add_files, del_files, modify_files) =
            Self::diff_local_remote_file(&l_metadata, &remote_metadata);

        // 执行相关操作
        match status {
            FileStatusEnumMsg::UPLOAD => {
                Self::upload_files(
                    &mut remote_metadata,
                    &mut add_files,
                    local_dir,
                    &remote_dir.value,
                    &client,
                )
                .await?;
                Self::delete_remote_files(
                    &mut remote_metadata,
                    &del_files,
                    &remote_dir.value,
                    &client,
                )
                .await?;
            }
            FileStatusEnumMsg::DOWNLOAD => {
                Self::download_files(
                    &mut remote_metadata,
                    &mut add_files,
                    local_dir,
                    &remote_dir.value,
                    &client,
                )
                .await?;
                Self::delete_local_files(&del_files, local_dir).await?;
            }
            FileStatusEnumMsg::SYNCED => {}
        }

        let mut upload_files = Vec::new();
        let mut download_files = Vec::new();
        for (file, status) in modify_files {
            match status {
                FileStatusEnumMsg::UPLOAD => {
                    upload_files.push(file);
                }
                FileStatusEnumMsg::DOWNLOAD => {
                    download_files.push(file);
                }
                FileStatusEnumMsg::SYNCED => {}
            }
        }
        Self::upload_files(
            &mut remote_metadata,
            &mut upload_files,
            local_dir,
            &remote_dir.value,
            &client,
        )
        .await?;
        Self::download_files(
            &mut remote_metadata,
            &download_files,
            local_dir,
            &remote_dir.value,
            &client,
        )
        .await?;

        // 更新远端文件属性
        let max = remote_metadata
            .files
            .values()
            .max()
            .as_deref()
            .unwrap_or(&0)
            .clone();
        remote_metadata.last_time = max;
        Self::update_remote_metadata(&remote_metadata, &remote_dir.value, &client).await?;

        // 返回数据
        upload_files.append(&mut download_files);
        Ok(SyncFileDetailMsg {
            status: status.into(),
            add_files,
            del_files,
            modify_files: upload_files,
        })
    }

    /// 新增一个同步文件夹条目
    async fn add_sync_dir(&mut self, sync: AddSyncDirMsg) -> Result<FileMsg> {
        // 1. 基本校验
        self.check_local_dir(&sync.local_dir)?;

        // 2. 构造远端目录
        let remote_dir =
            sha256(format!("{}_{}", get_machine_id()?, sync.local_dir).as_bytes()) + "/";
        let dir = format!("{}{remote_dir}", WEBDAV_SYNC_DIR);
        let client = self
            .client
            .as_ref()
            .ok_or_else(|| anyhow!("无登录信息，请先登录"))?;
        client.mkcol(&dir).await?;

        // 3. 构造空的文件属性
        let metadata = RemoteFileMedata {
            tag: sync.tag.clone(),
            last_time: 0,
            files: Default::default(),
        };
        Self::update_remote_metadata(&metadata, &remote_dir, &client).await?;
        self.file_sync
            .files
            .insert(remote_dir.clone(), sync.local_dir.clone());

        // 返回需要上传的所有文件
        let l_metadata = Self::get_newest_file(&sync.local_dir).await?;
        let result = FileMsg {
            local_dir: sync.local_dir,
            remote_dir,
            status: FileStatusEnumMsg::UPLOAD.into(),
            add: l_metadata.files.keys().len() as u32,
            del: 0,
            modify: 0,
            tag: sync.tag
        };
        Ok(result)
    }

    /// 对空缺的远端目录新增本地路径
    async fn add_local_file(&mut self, req: AddLocalForRemoteMsg) -> Result<FileMsg> {
        // 1. 基本校验
        // 本地校验
        self.check_local_dir(&req.local_dir)?;
        // 暂时取消
        // 判断本地文件夹是否非空
        // let mut entries = fs::read_dir(&req.local_dir).await?;
        // let entry = entries.next_entry().await?;
        // if entry.is_some() {
        //     return Err(anyhow!("添加的本地文件夹必须为空文件夹"));
        // }

        // 远端不校验
        self.file_sync
            .files
            .insert(req.remote_dir.clone(), req.local_dir.clone());

        // 获取远端数据
        let r_metadata =
            Self::get_remote_dir_metadatas(self.get_client()?, &req.remote_dir).await?;
        Ok(FileMsg {
            local_dir: req.local_dir,
            remote_dir: req.remote_dir,
            status: FileStatusEnumMsg::DOWNLOAD.into(),
            add: r_metadata.files.len() as u32,
            del: 0,
            modify: 0,
            tag: r_metadata.tag
        })
    }

    /// 删除本地路径
    fn del_local_dir(&mut self, local_dir: StringMsg) -> Result<()> {
        self.file_sync.files.retain(|_k, v| v != &local_dir.value);
        Ok(())
    }

    /// 删除远端路径(会将远端数据一并删除)
    async fn del_remote_dir(&mut self, remote_dir: StringMsg) -> Result<()> {
        let client = self
            .client
            .as_ref()
            .ok_or_else(|| anyhow!("无登录信息，请先登录"))?;
        let dir = format!("{}{}", WEBDAV_SYNC_DIR, remote_dir.value);
        client.delete(&dir).await?;
        self.file_sync.files.remove(&remote_dir.value);
        Ok(())
    }
}

impl SyncFileService {
    /// 连接webdav服务
    async fn connect(account: &AccountInfo) -> Result<Client> {
        let client = ClientBuilder::new()
            .set_host(account.url.to_string())
            .set_auth(Auth::Basic(
                account.user.to_owned(),
                account.passwd.to_owned(),
            ))
            .build()?;
        let _ = client.list("/", Depth::Number(0)).await?;

        if client
            .list(WEBDAV_SYNC_DIR, Depth::Number(0))
            .await
            .is_err()
        {
            client.mkcol(WEBDAV_SYNC_DIR).await?;
        }
        Ok(client)
    }

    /// 获取client
    fn get_client(&self) -> Result<&Client> {
        self.client
            .as_ref()
            .ok_or_else(|| anyhow!("无账户信息，请登录"))
    }

    /// 获取远端服务的所有文件夹绝对路由（String）及每一项的文件属性
    async fn get_remote_dirs(client: &Client) -> Result<AHashMap<String, RemoteFileMedata>> {
        let mut remote_files = AHashMap::new();
        let files = client.list(WEBDAV_SYNC_DIR, Depth::Number(1)).await?;
        for file in files.iter().skip(1) {
            if let ListEntity::Folder(dir) = file {
                if let Some(dir) = dir.href.split_once(WEBDAV_SYNC_DIR).map(|x| x.1) {
                    let dir = dir.to_string() + "/";
                    let metadata = Self::get_remote_dir_metadatas(&client, dir.as_str())
                        .await
                        .map_err(|x| anyhow!("无法获取远端文件夹属性文件{}修改时间 {}", dir, x))?;
                    remote_files.insert(dir, metadata);
                }
            }
        }

        Ok(remote_files)
    }

    /// 获取远端目录文件属性
    async fn get_remote_dir_metadatas(client: &Client, dir: &str) -> Result<RemoteFileMedata> {
        let dir = format!("{}{}{}", WEBDAV_SYNC_DIR, dir, METADATA_FILE);
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
            if entry.path().is_symlink() {
                continue;
            }

            let mut path = entry
                .path()
                .to_str()
                .unwrap()
                .strip_prefix(dir)
                .unwrap()
                .to_string();
            if entry.path().is_dir() {
                path += "/";
            }
            if path == "/" {
                continue;
            }
            path = path.replace(r"\", "/");
            let metadata = metadata(entry.path()).await?;
            let max = metadata.modified()?.duration_since(UNIX_EPOCH)?.as_millis();
            files.insert(path, max);
            max_time = max.max(max_time);
        }

        Ok(LocalFileMetadata {
            tag: String::with_capacity(0),
            last_time: max_time,
            files,
        })
    }

    /// 对比本地与远端文件差异
    /// 返回数据代表： (整体状态，需要新增的文件，需要删除的文件，需要修改的文件)
    fn diff_local_remote_file(
        l_metadata: &LocalFileMetadata,
        r_metadata: &RemoteFileMedata,
    ) -> (
        FileStatusEnumMsg,
        Vec<String>,
        Vec<String>,
        Vec<(String, FileStatusEnumMsg)>,
    ) {
        // 对比远端与本地文件差异
        let l_dirs: AHashSet<&String> = l_metadata.files.keys().collect();
        let r_dirs: AHashSet<&String> = r_metadata.files.keys().collect();
        let l_diff: Vec<String> = l_dirs.difference(&r_dirs).map(|x| x.to_string()).collect();
        let r_diff: Vec<String> = r_dirs.difference(&l_dirs).map(|x| x.to_string()).collect();
        let l_r_same: Vec<String> = l_dirs
            .intersection(&r_dirs)
            .map(|x| x.to_string())
            .collect();

        let status;
        let add_files;
        let del_files;
        let mut modify_files = Vec::new();
        if l_metadata.last_time > r_metadata.last_time {
            // 本地比远端新
            // 本地多出的文件要上传，远端多出的文件要删除
            add_files = l_diff;
            del_files = r_diff;
            status = FileStatusEnumMsg::UPLOAD;
        } else if l_metadata.last_time < r_metadata.last_time {
            // 远端比本地新
            // 本地多出的文件要删除，远端多出的文件要下载
            add_files = r_diff;
            del_files = l_diff;
            status = FileStatusEnumMsg::DOWNLOAD;
        } else {
            // 远端和本地一样新
            status = FileStatusEnumMsg::SYNCED;
            add_files = Vec::with_capacity(0);
            del_files = Vec::with_capacity(0);
        }

        for same_fir in l_r_same {
            let lf = l_metadata.files.get(&same_fir).unwrap();
            let rf = r_metadata.files.get(&same_fir).unwrap();
            if *lf > *rf {
                // 本地修改时间大于远端
                modify_files.push((same_fir, FileStatusEnumMsg::UPLOAD));
            } else if *lf < *rf {
                // 本地修改时间小于远端
                modify_files.push((same_fir, FileStatusEnumMsg::DOWNLOAD));
            }
        }

        (status, add_files, del_files, modify_files)
    }

    /// 上传文件
    async fn upload_files(
        remote_metadata: &mut RemoteFileMedata,
        local_files: &mut [String],
        local_dir: &str,
        remote_dir: &str,
        client: &Client,
    ) -> Result<()> {
        // 排序，这样文件依赖的文件夹路径一定存在于其之前
        local_files.sort();
        for file in local_files {
            let mut local_path = PathBuf::from(local_dir);
            for p in file.split("/") {
                if !p.is_empty() {
                    local_path.push(p);
                }
            }
            let remote_file = format!("{WEBDAV_SYNC_DIR}{remote_dir}{file}");
            if file.ends_with("/") {
                // 目录则新建目录
                client.mkcol(&remote_file).await?;
            } else {
                // 文件上传
                let mut local_file = File::open(&local_path).await?;
                let mut data = Vec::new();
                local_file.read_to_end(&mut data).await?;
                client.put(&remote_file, data).await?;
            }
            // 更新远端文件属性
            let metadata = metadata(local_path).await?;
            let modified = metadata.modified()?.duration_since(UNIX_EPOCH)?.as_millis();
            remote_metadata.files.insert(file.clone(), modified);
        }
        Ok(())
    }

    /// 删除远程文件
    async fn delete_remote_files(
        remote_metadata: &mut RemoteFileMedata,
        del_files: &[String],
        remote_dir: &str,
        client: &Client,
    ) -> Result<()> {
        for file in del_files {
            client
                .delete(&format!("{WEBDAV_SYNC_DIR}{remote_dir}{file}"))
                .await?;
            remote_metadata.files.remove(file);
        }
        Ok(())
    }
    /// 下载远端文件
    async fn download_files(
        remote_metadata: &mut RemoteFileMedata,
        add_files: &[String],
        local_dir: &str,
        remote_dir: &str,
        client: &Client,
    ) -> Result<()> {
        // 1. 创建文件夹
        for file in add_files {
            let mut path = PathBuf::from(local_dir);
            path.push(file);
            if !file.ends_with('/') {
                continue;
            }
            let mut path = PathBuf::from(local_dir);
            path.push(file);
            if !path.exists() {
                create_dir_all(path).await?;
            }
        }
        // 2. 下载文件
        for file in add_files {
            if file.ends_with('/') {
                continue;
            }
            let mut path = PathBuf::from(local_dir);
            path.push(file);
            let rsp = client
                .get(&format!("{WEBDAV_SYNC_DIR}{remote_dir}{file}"))
                .await?;
            let data = rsp.bytes().await?;
            let mut file = File::create(path).await?;
            file.write_all(&data).await?;
        }
        // 3. 修改时间戳
        for file in add_files {
            let time = *remote_metadata.files.get(file).unwrap();
            let mut path = PathBuf::from(local_dir);
            path.push(file);
            let system_time = SystemTime::UNIX_EPOCH.add(Duration::from_millis(time as u64));
            filetime::set_file_mtime(path, FileTime::from(system_time))?
        }

        Ok(())
    }

    /// 删除本地文件
    async fn delete_local_files(del_files: &[String], local_dir: &str) -> Result<()> {
        for file in del_files {
            let path = PathBuf::from(format!("{}{}", local_dir, file));
            tokio::fs::remove_file(path).await?;
        }
        Ok(())
    }

    /// 更新远端属性文件
    async fn update_remote_metadata(
        remote_file_medata: &RemoteFileMedata,
        remote_dir: &str,
        client: &Client,
    ) -> Result<()> {
        let dir = format!("{}{}{}", WEBDAV_SYNC_DIR, remote_dir, METADATA_FILE);
        client
            .put(&dir, Body::wrap(serde_json::to_string(remote_file_medata)?))
            .await?;
        Ok(())
    }

    /// 新增本地文件夹校验
    fn check_local_dir(&self, local_dir: &str) -> Result<()> {
        // 1. 基本校验
        let add_path = Path::new(local_dir);
        if !add_path.exists() || !add_path.is_dir() {
            return Err(anyhow!("{}路径不存在或非目录", local_dir));
        }

        // 2. 不允许存在路径包含关系
        for path in self.file_sync.files.values() {
            if path.starts_with(local_dir) || local_dir.starts_with(path) {
                return Err(anyhow!("设定路径存在包含关系: 已存在路径 {}", path));
            }
        }

        Ok(())
    }
}