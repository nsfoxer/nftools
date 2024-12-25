use crate::common::global_data::GlobalData;
use crate::messages::ai::{BaiduAiKeyReqMsg, BaiduAiRspMsg};
use crate::messages::common::StringMessage;
use crate::service::service::{Service, ServiceName, StreamService};
use crate::{async_func_nono, async_func_notype, async_func_typeno, async_stream_func_typeno, func_end};
use anyhow::Result;
use async_trait::async_trait;
use bytes::Bytes;
use futures_util::StreamExt;
use prost::Message;
use reqwest::Client;
use rinf::debug_print;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc::UnboundedSender;

#[derive(Deserialize)]
struct BaiduAiRsp {
    is_end: bool,
    is_truncated: bool,
    result: String,
}

#[derive(Deserialize)]
struct BaiduAiErrorRsp {
    error_code: usize,
    error_msg: String,
}

#[derive(Serialize)]
struct BaiduAiRequest {
    messages: Vec<InnerMessage>,
    stream: bool,
}
#[derive(Serialize)]
struct InnerMessage {
    role: String,
    content: String,
}

#[derive(Deserialize)]
struct BaiduTokenRsp {
    access_token: Option<String>,
    error_description: Option<String>,
}

const BAIDU_AI: &str = "BaiduAiService";
const APP_ID: &str = "BaiduAiService:APP_ID";
const SECRET: &str = "BaiduAiService:SECRET";

pub struct BaiduAiService {
    client: Client,
    gd: Arc<GlobalData>,
    token: Option<String>,
    app_id: Option<String>,
    secret: Option<String>,
}

impl BaiduAiService {
    pub fn new(gd: Arc<GlobalData>) -> Self {
        let client = Client::new();
        Self {
            client,
            token: None,
            app_id: gd.get_data(APP_ID),
            secret: gd.get_data(SECRET),
            gd,
        }
    }
}

impl ServiceName for BaiduAiService {
    fn get_service_name(&self) -> &'static str {
        BAIDU_AI
    }
}

#[async_trait]
impl StreamService for BaiduAiService {
    async fn handle_stream(
        &mut self,
        func: &str,
        req_data: Vec<u8>,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        async_stream_func_typeno!(self, func, req_data, question, StringMessage, tx);
        func_end!(func)
    }
}

#[async_trait]
impl Service for BaiduAiService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_notype!(self, func, get_kv);
        async_func_nono!(self, func, refresh_token);
        async_func_typeno!(self, func, req_data, set_kv, BaiduAiKeyReqMsg);
        func_end!(func)
    }
}

impl BaiduAiService {
    async fn question(
        &mut self,
        req: StringMessage,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        let mut msg = Vec::with_capacity(1);
        msg.push(InnerMessage {
            role: "user".to_string(),
            content: req.value,
        });
        let req = BaiduAiRequest {
            stream: true,
            messages: msg,
        };
        if self.token.is_none() {
            self.refresh_token().await?;
        }
        let mut stream = self.client
                .post(&format!( "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/yi_34b_chat?access_token={}", self.token.as_ref().unwrap()))
                .json(&req).send().await?.bytes_stream();

        while let Some(info) = stream.next().await {
            let data = match Self::parser_rsp(info) {
                Ok(data) => {
                    if data.is_none() {
                        continue;
                    }
                    Ok(Some(data.unwrap().encode_to_vec()))
                }
                Err(e) => Err(e),
            };
            if let Err(e) = tx.send(data) {
                panic!("发送通道已关闭: {}", e);
            }
        }

        Ok(())
    }
    fn parser_rsp(info: reqwest::Result<Bytes>) -> Result<Option<BaiduAiRspMsg>> {
        let info = info?;
        let info = String::from_utf8_lossy(info.as_ref());
        if info.trim().is_empty() {
            return Ok(None);
        }
        debug_print!("{}", info);
        if !info.starts_with("data:") {
            let error = serde_json::from_str::<BaiduAiErrorRsp>(&info)?;
            if error.error_code == 336002 {
                return Err(anyhow::anyhow!("token已失效,请手动刷新token"));
            }
            return Err(anyhow::anyhow!(error.error_msg));
        }
        let rsp: BaiduAiRsp = serde_json::from_str(info.trim_start_matches("data:"))?;
        Ok(Some(BaiduAiRspMsg {
            content: rsp.result,
        }))
    }
}

impl BaiduAiService {
    /// 刷新token
    async fn refresh_token(&mut self) -> Result<()> {
        let app_id = self.app_id.as_ref().ok_or(anyhow::anyhow!("appid未设置"))?;
        let secret = self.secret.as_ref().ok_or(anyhow::anyhow!("secret未设置"))?;
        let rsp = self.client
            .post(&format!("https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id={app_id}&client_secret={secret}"))
            .header("Content-Type", "application/json")
            .send().await?;
        let token =  rsp.json::<BaiduTokenRsp>().await?;
        if token.error_description.is_some() {
            return Err(anyhow::anyhow!(token.error_description.unwrap()));
        }

        self.token = Some(token.access_token.ok_or(anyhow::anyhow!("无法获取token"))?);
        Ok(())
    }

    /// 设置API Key与应用Secret Key
    async fn set_kv(&mut self, req: BaiduAiKeyReqMsg) -> Result<()> {
        let _ = self.gd.set_data(APP_ID.to_string(), &req.api_key);
        let _ = self.gd.set_data(SECRET.to_string(), &req.secret);
        
        self.app_id = Some(req.api_key);
        self.secret = Some(req.secret);
        self.refresh_token().await?;
        Ok(())
    }

    /// 获取key和secret
    async fn get_kv(&mut self) -> Result<BaiduAiKeyReqMsg> {
        self.refresh_token().await?;
        Ok(BaiduAiKeyReqMsg {
            api_key: self.app_id.as_ref().unwrap().clone(),
            secret: self.secret.as_ref().unwrap().clone(),
        })
    }
}
