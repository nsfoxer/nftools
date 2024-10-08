use chrono::Local;
use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::str::FromStr;
use toml::value::Datetime;
use toml::Table;

/// 全局数据
pub struct GlobalData {
    inner_data: DashMap<String, Table>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GlobalDataCopy {
    inner_data: HashMap<String, Table>,
}
impl GlobalData {
    pub fn new() -> Self {
        Self {
            inner_data: DashMap::new(),
        }
    }

    pub fn set_data<T>(&self, key: String, value: &T) -> anyhow::Result<()>
    where
        T: Serialize,
    {
        let map = Table::try_from(value)?;
        self.inner_data.insert(key, map);
        Ok(())
    }

    pub fn get_data<'de, T>(&self, key: &str) -> Option<T>
    where
        T: Deserialize<'de>,
    {
        self.inner_data.get(key).and_then(|v| {
            v.value().clone().try_into().ok()
        }) 
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

impl From<GlobalData> for GlobalDataCopy {
    fn from(value: GlobalData) -> Self {
        let mut datas = HashMap::with_capacity(value.inner_data.len());
        for (k, v) in value.inner_data {
            datas.insert(k, v);
        }

        Self {
            inner_data: datas,
        }
    }
}

fn now() -> Datetime {
    let time = Local::now();
    let time = time.format("%Y-%m-%dT%H:%M:%S").to_string();
    Datetime::from_str(&time).unwrap()
}

