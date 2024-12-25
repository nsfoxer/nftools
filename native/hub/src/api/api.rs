use crate::messages::base::{BaseRequest, BaseResponse};
use crate::service::service::{ImmService, LazyService, Service, StreamService};
use crate::service_handle;
use ahash::AHashMap;
use rinf::{debug_print, DartSignal};
use std::ops::DerefMut;
use std::sync::Arc;
use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};
use tokio::sync::Mutex;

/// 服务类型枚举
#[allow(dead_code)]
enum ServiceEnum {
    /// 惰性服务
    LazyService(Arc<Mutex<(Box<dyn LazyService>, bool)>>),
    /// 服务
    Service(Arc<Mutex<Box<dyn Service>>>),
    /// 不可变服务
    ImmService(Arc<Box<dyn ImmService>>),
}

/// stream服务类型枚举
#[allow(dead_code)]
enum StreamServiceEnum {
    /// stream响应服务
    StreamService(Arc<Mutex<Box<dyn StreamService>>>),
}

/// 服务分发
pub struct ApiService {
    services: AHashMap<&'static str, ServiceEnum>,
    stream_services: AHashMap<&'static str, StreamServiceEnum>,
}

impl ApiService {
    /// new
    pub fn new() -> Self {
        ApiService {
            services: AHashMap::new(),
            stream_services: AHashMap::new(),
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
    #[allow(dead_code)]
    pub fn add_lazy_service(&mut self, service: Box<dyn LazyService>) {
        self.services.insert(
            service.get_service_name(),
            ServiceEnum::LazyService(Arc::from(Mutex::from((service, false)))),
        );
    }
    /// 新增不可变服务
    #[allow(dead_code)]
    pub fn add_imm_service(&mut self, service: Box<dyn ImmService>) {
        self.services.insert(
            service.get_service_name(),
            ServiceEnum::ImmService(Arc::from(service)),
        );
    }

    /// 新增stream服务
    pub fn add_stream_service(&mut self, service: Box<dyn StreamService>) {
        self.stream_services.insert(
            service.get_service_name(),
            StreamServiceEnum::StreamService(Arc::from(Mutex::from(service))),
        );
    }

    /// 处理服务
    /// 如果该服务已被使用，则阻塞
    pub fn handle(&self, signal: DartSignal<BaseRequest>) {
        if signal.message.is_stream {
            // 流式服务处理
            self.handle_stream(signal);
            return;
        }
        // 一般服务处理
        let Some(service) = self.services.get(signal.message.service.as_str()) else {
            // 如果一般性服务也没有，则再次查找stream服务
            match self.stream_services.get(signal.message.service.as_str()) {
                None => {
                    generate_error_response(
                        signal.message.id,
                        format!("未知服务 {}", signal.message.service),
                        false
                    )
                        .send_signal_to_dart(Vec::with_capacity(0));
                }
                Some(service) => {
                    Self::handle_stream_service_for_service(service, signal);
                }
            }
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
    
    /// 流式服务处理
    fn handle_stream(&self, signal: DartSignal<BaseRequest>) {
        let Some(service) = self.stream_services.get(signal.message.service.as_str()) else {
            generate_error_response(
                signal.message.id,
                format!("未知服务 {}", signal.message.service),
                true
            )
            .send_signal_to_dart(Vec::with_capacity(0));
            return;
        };
        
        let (tx, mut rx) = unbounded_channel::<anyhow::Result<Option<Vec<u8>>>>();
        
        // 接受并发送响应流
        let id = signal.message.id;
        let msg_service = signal.message.service.clone();
        let func = signal.message.func.clone();
        tokio::spawn(async move {
            while let Some(result) = rx.recv().await {
                debug_print!("stream收到一条消息");
                match result {
                    Ok(r) => {
                        BaseResponse {
                            id,
                            msg: String::with_capacity(0),
                            is_stream: true,
                            is_end: false,
                        }.send_signal_to_dart(r.unwrap_or(Vec::with_capacity(0)));
                    }
                    Err(r) => {
                        BaseResponse {
                            id,
                            msg: format!("请求处理错误:{}-{}-{}", msg_service, func, r),
                            is_stream: true,
                            is_end: false,
                        }
                       .send_signal_to_dart(Vec::with_capacity(0));
                    }
                }
            }
            // 管道关闭后，发送结束标识
            BaseResponse {
                id, 
                msg: String::with_capacity(0),
                is_stream:true,
                is_end: true,
            }.send_signal_to_dart(Vec::with_capacity(0));
            debug_print!("stream已关闭");
        });
        
        match service {
            StreamServiceEnum::StreamService(service) => {
                Self::stream_service_handle(service.clone(), signal, tx);
            }
        }
    }
    
    fn stream_service_handle(service: Arc<Mutex<Box<dyn StreamService>>>,
                             signal: DartSignal<BaseRequest>,
                             tx: UnboundedSender<anyhow::Result<Option<Vec<u8>>>>) {
        tokio::spawn(async move {
            let mut service = service.lock().await;
            let tx_clone = tx.clone();
            if let Err(e) = service.handle_stream(&signal.message.func, signal.binary, tx).await {
                tx_clone.send(Err(e)).unwrap();
            }
        });
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
    
    async fn _handle_stream_service(
        service: Arc<Mutex<Box<dyn StreamService>>>,
        func: &str,
        data: Vec<u8>,
    ) -> anyhow::Result<Vec<u8>> {
        let mut service = service.lock().await;
        Ok(service
            .handle(func, data)
            .await?
            .unwrap_or(Vec::with_capacity(0)))
    }

    fn handle_stream_service_for_service(service: &StreamServiceEnum, signal: DartSignal<BaseRequest>) {
        match service { 
            StreamServiceEnum::StreamService(service) => {
                let service = service.clone();
                tokio::spawn(async move {
                    service_handle!(_handle_stream_service, service, signal);
                });
            }
        }
    }
}

/// 生成错误响应
fn generate_error_response(id: u64, error: String, is_stream: bool) -> BaseResponse {
    BaseResponse { id, msg: error, is_stream, is_end: true, }
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
                        is_stream: false,
                        is_end: true,
                    }
                    .send_signal_to_dart(r);
                }
                Err(e) => {
                    generate_error_response(
                        $signal.message.id,
                        format!(
                            "处理请求错误{}-{}:{}",
                            $signal.message.service, $signal.message.func, e
                        ),
                        false
                    )
                    .send_signal_to_dart(Vec::with_capacity(0));
                }
            }
        };
    }
}

