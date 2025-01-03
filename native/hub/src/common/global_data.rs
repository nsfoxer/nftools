use crate::common::utils::get_config_dir;
use anyhow::Result;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio_rusqlite::{params, Connection};

type KEY = &'static str;

pub enum ConfigMessage {
    STORE(KEY, String),
    LOAD(KEY, String),
}

/// 全局数据
#[derive(Clone)]
pub struct GlobalData {
    conn: Connection,
}

impl GlobalData {
    pub async fn new() -> Result<Self> {
        let conn = Connection::open(config_dir()?).await?;
        conn.call(|conn| {
            conn.execute(
                r#"
CREATE TABLE IF NOT EXISTS KV (
	id TEXT NOT NULL,
	value TEXT,
	CONSTRAINT KV_PK PRIMARY KEY (id)
);"#,
                [],
            )?;
            Ok(())
        })
        .await?;

        Ok(Self { conn })
    }

    pub async fn set_data<T>(&self, key: String, value: &T) -> Result<()>
    where
        T: Serialize,
    {
        let s = serde_json::to_string(value)?;
        self.store(key, s).await?;
        Ok(())
    }

    pub async fn get_data<T>(&self, key: String) -> Option<T>
    where
        T: DeserializeOwned,
    {
        match self.load(key).await {
            Ok(v) => match v {
                None => None,
                Some(v) => serde_json::from_str(v.as_str()).ok(),
            },
            Err(_) => None,
        }
    }

    async fn store(&self, key: String, value: String) -> Result<()> {
        self.conn
            .call(move |conn| {
                let mut stmt =
                    conn.prepare_cached("INSERT OR REPLACE INTO KV (id, value) values (?1, ?2)")?;
                stmt.execute(&[&key, &value])?;
                Ok(())
            })
            .await?;
        Ok(())
    }

    async fn load(&self, key: String) -> Result<Option<String>> {
        let result = self
            .conn
            .call(move |conn| {
                let mut stmt = conn.prepare_cached("SELECT value FROM KV WHERE id = ?1")?;
                let mut rows = stmt.query(params![key])?;
                match rows.next()? {
                    None => Ok(None),
                    Some(row) => Ok(row.get(0)?),
                }
            })
            .await?;
        Ok(result)
    }
}

fn config_dir() -> Result<PathBuf> {
    let mut config = get_config_dir()?;
    config.push("global.db");
    Ok(config)
}

mod tests {
    #[test]
    fn a() {}
    #[test]
    fn b() {}
}
