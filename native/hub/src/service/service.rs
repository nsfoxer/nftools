use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use async_trait::async_trait;
use crate::messages::base::{BaseRequest, BaseResponse};

/// 服务
#[async_trait]
pub trait Service {
    fn get_service_name(&self) -> &'static str;

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> crate::common::Result<Option<Vec<u8>>>;
}

/// 服务分发
struct ApiService {
    services: HashMap<&'static str, Arc<Mutex<Box<dyn Service>>>>,
}

impl ApiService {
    /// new
    pub fn new() -> Self {
        ApiService {
            services: HashMap::new(),
        }
    }

    /// 新增服务
    pub fn add_service(&mut self, service: Box<dyn Service>) {
        self.services.insert(service.get_service_name(), Arc::from(Mutex::from(service)));
    }
    
    /// 处理服务
    /// 如果该服务已被使用，则阻塞
    pub fn handle(&self, request: BaseRequest) -> BaseResponse {
        let id = request.id;
        let service = match self.services.get(request.service.as_str()) {
            None => {
                return generate_error_response(id, format!("未知服务 {}", request.service));
            }
            Some(s) => {s}
        };
        
        // todo
        
        unimplemented!()
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