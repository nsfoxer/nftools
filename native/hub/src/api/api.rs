use std::ops::DerefMut;
use crate::messages::base::{BaseRequest, BaseResponse};
use crate::service::service::{ImmService, LazyService, Service};
use crate::service_handle;
use ahash::AHashMap;
use std::sync::Arc;
use rinf::DartSignal;
use tokio::sync::Mutex;

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
pub struct ApiService {
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
    pub fn handle(&self, signal: DartSignal<BaseRequest>) {
        // 获取服务
        let Some(service) = self.services.get(signal.message.service.as_str()) else {
            generate_error_response(signal.message.id, format!("未知服务 {}", signal.message.service))
                .send_signal_to_dart(Vec::with_capacity(0));
            return;
        };

        // 执行服务
        match service {
            ServiceEnum::LazyService(service) => {
                Self::lazy_service_handle(service.clone(), signal);
            }
            ServiceEnum::Service(service) => {
                Self::service_handle(service.clone(), signal);
            }
            ServiceEnum::ImmService(service) => {
                Self::imm_service_handle(service.clone(), signal);
            }
        };
    }

    fn lazy_service_handle(
        service: Arc<Mutex<(Box<dyn LazyService>, bool)>>,
        signal: DartSignal<BaseRequest>,
    ) {
        tokio::spawn(async move {
            service_handle!(_lazy_handle, service, signal);
        });
    }

    async fn _lazy_handle(
        service: Arc<Mutex<(Box<dyn LazyService>, bool)>>,
        func: &str,
        data: Vec<u8>,
    ) -> anyhow::Result<Vec<u8>> {
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

    fn service_handle(service: Arc<Mutex<Box<dyn Service>>>, signal: DartSignal<BaseRequest>) {
        tokio::spawn(async move {
            service_handle!(_handle, service, signal);
        });
    }

    async fn _handle(
        service: Arc<Mutex<Box<dyn Service>>>,
        func: &str,
        data: Vec<u8>,
    ) -> anyhow::Result<Vec<u8>> {
        let mut service = service.lock().await;
        Ok(service
            .handle(func, data)
            .await?
            .unwrap_or(Vec::with_capacity(0)))
    }

    fn imm_service_handle(service: Arc<Box<dyn ImmService>>, signal: DartSignal<BaseRequest>) {
        tokio::spawn(async move {
            service_handle!(_imm_handle, service, signal);
        });
    }

    async fn _imm_handle(
        service: Arc<Box<dyn ImmService>>,
        func: &str,
        data: Vec<u8>,
    ) -> anyhow::Result<Vec<u8>> {
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
    }
}

mod macros {
    #[macro_export]
    macro_rules! service_handle {
        ($func: ident, $service: ident, $signal: ident) => {
            match Self::$func($service, &$signal.message.func, $signal.binary).await {
                Ok(r) => {
                    BaseResponse {
                        id: $signal.message.id,
                        msg: String::with_capacity(0),
                    }
                    .send_signal_to_dart(r);
                }
                Err(e) => {
                    generate_error_response(
                        $signal.message.id,
                        format!("处理请求错误{}-{}:{}", $signal.message.service, $signal.message.func, e),
                    )
                    .send_signal_to_dart(Vec::with_capacity(0));
                }
            }
        };
    }
}
