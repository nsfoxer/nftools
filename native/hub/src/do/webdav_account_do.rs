use reqwest_dav::re_exports::serde::{Deserialize, Serialize};
use crate::common::global_data::{DataPersist};

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct WebDavAccountDO {
    pub url: String,
    pub account: String,
    pub passwd: String,
}

impl DataPersist for WebDavAccountDO {
    fn id() -> &'static str {
        "WebDavAccount"
    }
}
