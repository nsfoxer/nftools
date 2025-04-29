use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

// 配置webdav
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct WebDavConfigMsg {
    pub url: String,
    pub account: String,
    pub passwd: String,
}

// 文件列表响应
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct ListFileMsg {
    pub files: Vec<FileMsg>,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct FileMsg {
    // 本地地址
    pub local_dir: String,
    // 远端地址 同时为唯一id
    pub remote_dir: String,
    // 同步状态
    pub status: FileStatusEnumMsg,
    // 需要新增的文件数量
    pub add: u32,
    // 需要删除的文件数量
    pub del: u32,
    // 需要修改的文件数量
    pub modify: u32,
    // 标签
    pub tag: String,
}

// 同步文件详情
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct SyncFileDetailMsg {
    // 同步状态
    pub status: FileStatusEnumMsg,
    // 新增的文件
    pub add_files: Vec<String>,
    // 删除的文件
    pub del_files: Vec<String>,
    // 同步的文件
    pub modify_files: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub enum FileStatusEnumMsg {
    // 需要上传
    UPLOAD = 0,
    // 需要下载
    DOWNLOAD = 1,
    // 已同步成功
    SYNCED = 2,
}

// 对空缺的远端目录新增本地路径
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct AddLocalForRemoteMsg {
    pub local_dir: String,
    pub remote_dir: String,
}

// 新增同步文件夹
#[derive(Debug, Serialize, Deserialize, SignalPiece)]
pub struct AddSyncDirMsg {
    // 本地路径
    pub local_dir: String,
    // tag
    pub tag: String,
}