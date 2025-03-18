use crate::messages::base::{BaseRequest, BaseResponse};
use crate::service::service::{ImmService, LazyService, Service, StreamService};
use crate::{async_func_notype, async_func_typeno, func_end, service_handle};
use ahash::AHashMap;
use futures_util::SinkExt;
use log::error;
use rinf::DartSignal;
use std::ops::DerefMut;
use std::sync::Arc;
use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};
use tokio::sync::Mutex;
use prost::Message;
use crate::common::global_data::GlobalData;
use crate::messages::common::StringMessage;
use crate::service::ai::BaiduAiService;
use crate::service::display::display_os::{DisplayLight, DisplayMode};
use crate::service::settings::about::AboutService;
use crate::service::settings::autostart::AutoStartService;
use crate::service::syncfile::SyncFileService;
use crate::service::utils::UtilsService;

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

const BASE_SERVICE:&str = "BaseService";

/// 服务分发
pub struct ApiService {
    services: AHashMap<&'static str, ServiceEnum>,
    stream_services: AHashMap<&'static str, StreamServiceEnum>,
    global_data: GlobalData,
}

impl ApiService {
    /// new
    pub fn new(global_data: GlobalData) -> Self {
        ApiService {
            services: AHashMap::new(),
            stream_services: AHashMap::new(),
            global_data
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
                        false,
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

    pub async fn close(self, signal: DartSignal<BaseRequest>) -> BaseResponse{
        let mut handles = Vec::new();
        // 关闭所有服务
        for (desc, service) in self.services {
            let handle = match service {
                ServiceEnum::LazyService(service) => tokio::spawn(async move {
                    let mut s = service.lock().await;
                    if !s.1 {
                        if let Err(e) = s.0.close().await {
                            error!("关闭服务{}失败 {}", desc, e);
                        }
                    }
                }),
                ServiceEnum::Service(service) => tokio::spawn(async move {
                    let mut s = service.lock().await;
                    if let Err(e) = s.close().await {
                        error!("关闭服务{}失败 {}", desc, e);
                    }
                }),
                ServiceEnum::ImmService(service) => tokio::spawn(async move {
                    if let Err(e) = service.close().await {
                        error!("关闭服务{}失败 {}", desc, e);
                    }
                }),
            };
            handles.push(handle);
        }
        for (desc, service) in self.stream_services {
            let handle = match service {
                StreamServiceEnum::StreamService(service) => tokio::spawn(async move {
                    if let Err(e) = service.lock().await.close().await {
                        error!("关闭服务{}失败 {}", desc, e);
                    }
                }),
            };
            handles.push(handle);
        }

        // 等待任务全部结束
        futures::future::join_all(handles).await;
        // 发送完成信息
        BaseResponse {
            id: signal.message.id,
            msg: String::with_capacity(0),
            is_stream: false,
            is_end: false,
        }
    }

    /// 流式服务处理
    fn handle_stream(&self, signal: DartSignal<BaseRequest>) {
        let Some(service) = self.stream_services.get(signal.message.service.as_str()) else {
            generate_error_response(
                signal.message.id,
                format!("未知服务 {}", signal.message.service),
                true,
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
                match result {
                    Ok(r) => {
                        BaseResponse {
                            id,
                            msg: String::with_capacity(0),
                            is_stream: true,
                            is_end: false,
                        }
                        .send_signal_to_dart(r.unwrap_or(Vec::with_capacity(0)));
                    }
                    Err(r) => {
                        let msg = if cfg!(debug_assertions) {
                            format!("处理请求错误{}-{}:{}", msg_service, func, r)
                        } else {
                            r.to_string()
                        };
                        BaseResponse {
                            id,
                            msg,
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
                is_stream: true,
                is_end: true,
            }
            .send_signal_to_dart(Vec::with_capacity(0));
        });

        match service {
            StreamServiceEnum::StreamService(service) => {
                Self::stream_service_handle(service.clone(), signal, tx);
            }
        }
    }

    fn stream_service_handle(
        service: Arc<Mutex<Box<dyn StreamService>>>,
        signal: DartSignal<BaseRequest>,
        tx: UnboundedSender<anyhow::Result<Option<Vec<u8>>>>,
    ) {
        tokio::spawn(async move {
            let mut service = service.lock().await;
            let tx_clone = tx.clone();
            if let Err(e) = service
                .handle_stream(&signal.message.func, signal.binary, tx)
                .await
            {
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

    fn handle_stream_service_for_service(
        service: &StreamServiceEnum,
        signal: DartSignal<BaseRequest>,
    ) {
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
    BaseResponse {
        id,
        msg: error,
        is_stream,
        is_end: true,
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
                        is_stream: false,
                        is_end: true,
                    }
                    .send_signal_to_dart(r);
                }
                Err(e) => {
                    let msg = if cfg!(debug_assertions) {
                        format!(
                            "处理请求错误{}-{}:{}",
                            $signal.message.service, $signal.message.func, e
                        )
                    } else {
                        e.to_string()
                    };
                    generate_error_response($signal.message.id, msg, false)
                        .send_signal_to_dart(Vec::with_capacity(0));
                }
            }
        };
    }
}

impl ApiService {
    /// api服务处理
    pub async fn api_handle(&mut self, signal: DartSignal<BaseRequest>) {
        let id = signal.message.id;
        match self.inner_handle(signal).await{
            Ok(r) => {
                BaseResponse {
                    id,
                    msg: String::with_capacity(0),
                    is_stream: false,
                    is_end: false,
                }.send_signal_to_dart(r.unwrap_or(Vec::with_capacity(0)));
            }
            Err(e) => {
                BaseResponse {
                    id, 
                    msg: e.to_string(),
                    is_stream: false,
                    is_end: false,
                }.send_signal_to_dart(Vec::with_capacity(0));
            }
        };
    }
    
    async fn inner_handle(&mut self, signal: DartSignal<BaseRequest>) -> anyhow::Result<Option<Vec<u8>>> {
        let func = signal.message.func.as_str();
        let data = signal.binary;
        
        async_func_typeno!(self, func, data, enable_service, StringMessage);
        
        func_end!(func)
    }


    const UTIL_PAGE: &'static str = "SyncFilePage";
    const SYNC_FILE_PAGE: &'static str = "SyncFilePage";
    const AUTO_START_PAGE: &'static str = "AutoStartPage";
    const DISPLAY_PAGE: &'static str = "DisplayPage";
    const ABOUT_PAGE: &'static str = "AboutPage";
    const AI_PAGE: &'static str = "AiPage";
    
    async fn enable_service(&mut self, service: StringMessage) -> anyhow::Result<()> {
        let service = service.value;
        
        if service == Self::UTIL_PAGE {
            self.add_imm_service(Box::new(UtilsService::new()));
        }
        
        if service == Self::SYNC_FILE_PAGE {
            let service = SyncFileService::new(self.global_data.clone()).await?;
            self.add_service(Box::new(service));
        } 
        
        if service == Self::AUTO_START_PAGE {
            self.add_imm_service(Box::new(AutoStartService::new()?));
        }
        
        if service == Self::ABOUT_PAGE {
            self.add_service(Box::new(AboutService::new()));
        }
        
        if service == Self::DISPLAY_PAGE {
            #[cfg(target_os = "windows")]
            {
                self.add_imm_service(Box::new(DisplayLight::new()));
                self.add_lazy_service(Box::new(DisplayMode::new(self.global_data.clone()).await));
            }
            #[cfg(target_os = "linux")]
            {
                if let Some(display) = DisplayLight::new().await {
                    api.add_service(Box::new(display));
                } else {
                    error!("display light 服务创建失败");
                }

                match DisplayMode::new(gd.clone()).await {
                    Ok(mode) => api.add_service(Box::new(mode)),
                    Err(e) => error!("display mode服务创建失败。原因:{e}"),
                }
            }
        }
        
        if service == Self::AI_PAGE {
            self.add_stream_service(Box::new(BaiduAiService::new(self.global_data.clone()).await));
        }
        
        Ok(())
    }
}