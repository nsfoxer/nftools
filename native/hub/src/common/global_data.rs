use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::create_dir_all;
use std::path::PathBuf;
use dirs::config_local_dir;
use anyhow::Result;
use serde::de::DeserializeOwned;
use crate::common::utils::get_config_dir;

/// 全局数据
pub struct GlobalData {
    inner_data: DashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GlobalDataCopy {
    inner_data: HashMap<String, String>,
}
impl GlobalData {
    pub fn new() -> Result<Self> {
        let gd = GlobalDataCopy::new()?;
        Ok(gd.into())
    }

    pub fn set_data<T>(&self, key: String, value: &T) -> Result<()>
    where
        T: Serialize,
    {
        let s = serde_json::to_string(value)?;
        self.inner_data.insert(key, s);
        Ok(())
    }

    pub fn get_data<T>(&self, key: &str) -> Option<T>
    where
        T: DeserializeOwned,
    {
        self.inner_data.get(key).and_then(|v| {
            serde_json::from_str(v.value().as_str()).ok()
        })
    }
}


impl Drop for GlobalData {
    fn drop(&mut self) {
        let data: GlobalDataCopy = self.into();
        data.save().unwrap_or_else(|e| eprintln!("{}", e));
    }
}

impl From<GlobalDataCopy> for GlobalData {
    fn from(value: GlobalDataCopy) -> Self {
        let datas = DashMap::with_capacity(value.inner_data.len());
        for (k, v) in value.inner_data {
            datas.insert(k, v);
        }

        Self {
            inner_data: datas,
        }
    }
}

impl From<&mut GlobalData> for GlobalDataCopy {
    fn from(value: &mut GlobalData) -> Self {
        let mut datas = HashMap::with_capacity(value.inner_data.len());
        for (k, v) in value.inner_data.clone() {
            datas.insert(k, v);
        }

        Self {
            inner_data: datas,
        }
    }
}

impl GlobalDataCopy {
    fn new() -> Result<Self> {
        let config = config_dir()?;

        let data =
            if config.exists() {
                serde_json::from_str(&std::fs::read_to_string(config).unwrap_or_default()).unwrap_or_else(|e| {
                    eprintln!("{}", e);
                    HashMap::with_capacity(0)
                })
            } else {
                HashMap::with_capacity(0)
            };

        Ok(Self {
            inner_data: data,
        })
    }

    fn save(self) -> Result<()> {
        let config = config_dir()?;
        std::fs::write(config, serde_json::to_string(&self.inner_data)?)?;
        Ok(())
    }
}


fn config_dir() -> Result<PathBuf> {
    let mut config = get_config_dir()?;
    config.push("global.json");
    Ok(config)
}


/// 数据存储服务
pub trait DataPersist: Serialize + DeserializeOwned {
    fn id() -> &'static str;

    fn set_data(&self, global_data: &GlobalData) -> Result<()> {
        global_data.set_data(Self::id().to_string(), self)
    }

    fn get_data(global_data: &GlobalData) -> Option<Self> {
        global_data.get_data(Self::id())
    }
}

mod tests {
    use crate::common::global_data::GlobalData;

    #[test]
    fn a() {
        let data = GlobalData::new().unwrap();
        let s = vec!["1", "2", "3", "abcb"];
        data.set_data("SyncFile".to_string(), &s).unwrap();
    }
    #[test]
    fn b() {
        let data = GlobalData::new().unwrap();
        eprintln!("{:?}", data.get_data::<Vec<String>>("SyncFile").unwrap());
    }
}