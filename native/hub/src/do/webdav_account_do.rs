use reqwest_dav::re_exports::serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Default)]
pub (in crate::service) struct WebDavAccountDO {
    url: String,
    account: String,
    passwd: String,
}
