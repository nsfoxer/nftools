use anyhow::Result;
use async_trait::async_trait;

/// 服务
#[async_trait]
pub trait Service: Send {
    /// 服务标识
    fn get_service_name(&self) -> &'static str;
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>>;
}

/// 惰性初始化服务
#[async_trait]
pub trait LazyService: Service {
    /// 惰性初始化
    async fn lazy_init_self(&mut self) -> Result<()>;
}

/// "无状态"服务 可多请求同时处理
#[async_trait]
pub trait ImmService: Send + Sync {
    /// 服务标识
    fn get_service_name(&self) -> &'static str;

    /// 实际处理
    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>>;
}
