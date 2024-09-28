use crate::messages::base::{BaseRequest, BaseResponse};
use ahash::AHashMap;
use anyhow::Result;
use async_trait::async_trait;
use std::ops::DerefMut;
use std::sync::Arc;
use tokio::sync::Mutex;
use crate::service_handle;

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

/// 服务类型枚举
enum ServiceEnum {
    /// 惰性服务
    LazyService(Arc<Mutex<(Box<dyn LazyService>, bool)>>),
    /// 服务
    Service(Arc<Mutex<Box<dyn Service>>>),
    // 不可变服务
    ImmService(Arc<Box<dyn ImmService>>),
}

/// 服务分发
struct ApiService {
    services: AHashMap<&'static str, ServiceEnum>,
}

impl ApiService {
    /// new
    pub fn new() -> Self {
        ApiService {
            services: AHashMap::new(),
        }
    }

    /// 新增服务
    pub fn add_service(&mut self, service: Box<dyn Service>) {
        self.services.insert(
            service.get_service_name(),
            ServiceEnum::Service(Arc::from(Mutex::from(service))),
        );
    }
    /// 新增惰性服务
    pub fn add_lazy_service(&mut self, service: Box<dyn LazyService>) {
        self.services.insert(
            service.get_service_name(),
            ServiceEnum::LazyService(Arc::from(Mutex::from((service, false)))),
        );
    }
    /// 新增不可变服务
    pub fn add_imm_service(&mut self, service: Box<dyn ImmService>) {
        self.services.insert(
            service.get_service_name(),
            ServiceEnum::ImmService(Arc::from(service)),
        );
    }

    /// 处理服务
    /// 如果该服务已被使用，则阻塞
    pub fn handle(&self, request: BaseRequest) {
        // 获取服务
        let Some(service) = self.services.get(request.service.as_str()) else {
            generate_error_response(request.id, format!("未知服务 {}", request.service))
                .send_signal_to_dart();
            return;
        };

        // 执行服务
        match service {
            ServiceEnum::LazyService(service) => {
                Self::lazy_service_handle(service.clone(), request);
            }
            ServiceEnum::Service(service) => {
                Self::service_handle(service.clone(), request);
            }
            ServiceEnum::ImmService(service) => {
                Self::imm_service_handle(service.clone(), request);
            }
        };
    }

    fn lazy_service_handle(
        service: Arc<Mutex<(Box<dyn LazyService>, bool)>>,
        request: BaseRequest,
    ) {
        tokio::spawn(async move {
            service_handle!(_lazy_handle, service, request);
        });
    }

    async fn _lazy_handle(
        service: Arc<Mutex<(Box<dyn LazyService>, bool)>>,
        func: &str,
        data: Vec<u8>,
    ) -> Result<Vec<u8>> {
        let mut service = service.lock().await;
        let (service, status) = service.deref_mut();
        // 初始化
        if !*status {
            *status = true;
            service.lazy_init_self().await?;
        }
        Ok(service
            .handle(func, data)
            .await?
            .unwrap_or(Vec::with_capacity(0)))
    }

    fn service_handle(service: Arc<Mutex<Box<dyn Service>>>, request: BaseRequest) {
        tokio::spawn(async move {
            service_handle!(_handle, service, request);
        });
    }

    async fn _handle(
        service: Arc<Mutex<Box<dyn Service>>>,
        func: &str,
        data: Vec<u8>,
    ) -> Result<Vec<u8>> {
        let mut service = service.lock().await;
        Ok(service
            .handle(func, data)
            .await?
            .unwrap_or(Vec::with_capacity(0)))
    }

    fn imm_service_handle(service: Arc<Box<dyn ImmService>>, request: BaseRequest) {
        tokio::spawn(async move {
            service_handle!(_imm_handle, service, request);
        });
    }

    async fn _imm_handle(
        service: Arc<Box<dyn ImmService>>,
        func: &str,
        data: Vec<u8>,
    ) -> Result<Vec<u8>> {
        Ok(service
            .handle(func, data)
            .await?
            .unwrap_or(Vec::with_capacity(0)))
    }
}

/// 生成错误响应
fn generate_error_response(id: u64, error: String) -> BaseResponse {
    BaseResponse {
        id,
        msg: error,
        response: Vec::with_capacity(0),
    }
}

mod macros {

#[macro_export]
macro_rules! service_handle {
    ($func: ident, $service: ident, $request: ident) => {
            match Self::$func($service, &$request.func, $request.request).await {
                Ok(r) => {
                    BaseResponse {
                        id: $request.id,
                        msg: String::with_capacity(0),
                        response: r,
                    }
                    .send_signal_to_dart();
                }
                Err(e) => {
                    generate_error_response(
                        $request.id,
                        format!("处理请求错误{}-{}:{}", $request.service, $request.func, e),
                    )
                    .send_signal_to_dart();
                }
            }
    };
}
}
