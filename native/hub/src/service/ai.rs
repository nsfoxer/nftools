use crate::messages::common::StringMessage;
use crate::service::service::{ServiceName, StreamService};
use anyhow::Result;
use async_trait::async_trait;
use bytes::Bytes;
use futures_util::StreamExt;
use prost::Message;
use reqwest::Client;
use rinf::debug_print;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::UnboundedSender;
use crate::{async_stream_func_typeno, func_end};
use crate::messages::ai::BaiduAiRspMsg;

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

const BAIDU_AI: &str = "BaiduAiService";

pub struct BaiduAiService {
    client: Client,
}

impl BaiduAiService {
    pub fn new() -> Self {
        let client = reqwest::Client::new();
        Self { client }
    }
}

impl ServiceName for BaiduAiService {
    fn get_service_name(&self) -> &'static str {
        BAIDU_AI
    }
}

#[async_trait]
impl StreamService for BaiduAiService {
    async fn handle(
        &mut self,
        func: &str,
        req_data: Vec<u8>,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        async_stream_func_typeno!(self, func, req_data, question, StringMessage, tx);
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
        let mut stream = self.client
                .post("https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/yi_34b_chat?access_token=24.23104fdfb30a1d1cec5560891e7bb6e0.2592000.1737605136.282335-116815013")
                .json(&req).send().await?.bytes_stream();

        while let Some(info) = stream.next().await {
            let data = match Self::parser_rsp(info) {
                Ok(data) => {
                    if data.is_none() {
                        continue;
                    }
                   Ok(Some(data.unwrap().encode_to_vec()))
                }
                Err(e) => {
                    Err(e)
                }
            };
            if let Err(e) =  tx.send(data) {
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
            return Err(anyhow::anyhow!(error.error_msg));
        }
        let rsp: BaiduAiRsp = serde_json::from_str(info.trim_start_matches("data:"))?;
        Ok(Some( BaiduAiRspMsg{
            content: rsp.result,
        }))
    }
}
