use crate::common::global_data::GlobalData;
use crate::messages::common::{BoolMsg, PairStringMsg, StringMsg};
use crate::service::service::ImmService;
use crate::{async_func_notype, async_func_typeno, async_func_typetype, func_end, func_typeno};
use anyhow::Result;

/// 工具类服务
pub struct UtilsService {
    global_data: GlobalData,
}

#[async_trait::async_trait]
impl ImmService for UtilsService {

    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_typetype!(
            self,
            func,
            req_data,
            get_data,
            StringMsg
        );
        async_func_notype!(self, func, network_status);
        async_func_typeno!(self, func, req_data, set_data, PairStringMsg);
        func_typeno!(self, func, req_data, notify, StringMsg);
        func_end!(func)
    }
}

impl UtilsService {
    pub fn new(global_data: GlobalData) -> Self {
        Self {
            global_data
        }
    }
}

impl UtilsService {

      /// 桌面通知
    fn notify(&self, body: StringMsg) -> Result<()> {
        crate::common::utils::notify(body.value.as_str())
    }

    /// 检查网络状态
    async fn network_status(&self) -> Result<BoolMsg> {
        let client = reqwest::Client::new();
        let response = client.get("https://www.baidu.com").send().await;
        
        Ok(BoolMsg{
            value: response.is_ok(),
        })
    }

    const FRONTED_DATA: &'static str = "fronted_key:";
    
    /// 存储数据
    async fn set_data(&self, msg: PairStringMsg) -> Result<()> {
        self.global_data.set_data(format!("{}{}", Self::FRONTED_DATA,msg.key), &msg.value).await?;
        Ok(())
    }
    
    /// 设置数据
    async fn get_data(&self, msg: StringMsg) -> Result<StringMsg> {
        let key = format!("{}{}", Self::FRONTED_DATA,msg.value);
        let value: String = self.global_data.get_data(key).await.ok_or(anyhow::anyhow!("{}不存在", msg.value))?;
        Ok(StringMsg{value})
    }
    
}