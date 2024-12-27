use crate::common::global_data::GlobalData;
use crate::messages::ai::{BaiduAiKeyReqMsg, BaiduAiRspMsg, QuestionListMsg, QuestionMsg};
use crate::messages::common::{Uint32Message, VecStringMessage};
use crate::service::service::{Service, ServiceName, StreamService};
use crate::{async_func_nono, async_func_notype, async_func_typeno, async_stream_func_typeno, func_end, func_notype, func_typeno, func_typetype};
use ahash::AHashMap;
use anyhow::Result;
use async_trait::async_trait;
use bytes::Bytes;
use futures_util::StreamExt;
use prost::Message;
use reqwest::Client;
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
    role: RoleEnum,
    content: String,
}

#[derive(Deserialize)]
struct BaiduTokenRsp {
    access_token: Option<String>,
    error_description: Option<String>,
}

#[derive(Serialize)]
enum RoleEnum {
    #[serde(rename = "user")]
    User,
    #[serde(rename = "assistant")]
    Assistant,
}

const BAIDU_AI: &str = "BaiduAiService";
const APP_ID: &str = "BaiduAiService:APP_ID";
const SECRET: &str = "BaiduAiService:SECRET";
const HISTORY: &str = "BaiduAiService:HISTORY";

pub struct BaiduAiService {
    client: Client,
    gd: Arc<GlobalData>,
    token: Option<String>,
    app_id: Option<String>,
    secret: Option<String>,
    // 所有的历史数据
    history: AHashMap<u32, Vec<String>>,
}

impl BaiduAiService {
    pub fn new(gd: Arc<GlobalData>) -> Self {
        let client = Client::new();
        let history = gd.get_data(HISTORY).unwrap_or(AHashMap::new());
        Self {
            client,
            token: None,
            app_id: gd.get_data(APP_ID),
            secret: gd.get_data(SECRET),
            gd,
            history,
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
        async_stream_func_typeno!(self, func, req_data, question, QuestionMsg, tx);
        func_end!(func)
    }
}

#[async_trait]
impl Service for BaiduAiService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        async_func_notype!(self, func, get_kv);
        async_func_nono!(self, func, refresh_token);
        async_func_typeno!(self, func, req_data, set_kv, BaiduAiKeyReqMsg);
        func_notype!(self, func, get_question_list);
        func_typetype!(self, func, req_data, get_question, Uint32Message);
        func_typeno!(self, func, req_data, new_question, Uint32Message, del_question, Uint32Message);
        func_end!(func)
    }
}

const MAX_SIZE: usize = 8000;

impl BaiduAiService {
    async fn question(
        &mut self,
        req: QuestionMsg,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        if !self.history.contains_key(&req.id) {
            return Err(anyhow::anyhow!("没有对应的对话id"));
        }
        let current_size = req.desc.len();
        if current_size > MAX_SIZE {
            return Err(anyhow::anyhow!("提问最大长度为8000"));
        }

        // 对最大长度字符8000进行限制
        let mut sum_size = current_size;
        let msg = self.history.get(&req.id).unwrap().iter().rev();
        let mut history_msg = Vec::new();
        for msg in msg {
            sum_size += msg.len();
            if sum_size <= MAX_SIZE {
                history_msg.push(msg);
            }
        }
        if !history_msg.is_empty() && history_msg.len() % 2 != 0 {
            history_msg.remove(history_msg.len() - 1);
        }
        // 转换为inner msg
        let mut msg = history_msg
            .iter()
            .rev()
            .enumerate()
            .map(|(i, v)| {
                if i % 2 == 0 {
                    InnerMessage {
                        role: RoleEnum::User,
                        content: v.to_string(),
                    }
                } else {
                    InnerMessage {
                        role: RoleEnum::Assistant,
                        content: v.to_string(),
                    }
                }
            })
            .collect::<Vec<InnerMessage>>();
        msg.push(InnerMessage {
            role: RoleEnum::User,
            content: req.desc.to_string(),
        });

        // 发起请求
        let id = req.id;
        let desc = req.desc;
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

        let mut result = String::new();
        while let Some(info) = stream.next().await {
            let data = match Self::parser_rsp(info) {
                Ok(data) => {
                    if data.is_none() {
                        continue;
                    }
                    let data = data.unwrap();
                    result.push_str(data.content.as_str());
                    Ok(Some(data.encode_to_vec()))
                }
                Err(e) => Err(e),
            };
            if let Err(e) = tx.send(data) {
                panic!("发送通道已关闭: {}", e);
            }
        }

        // 保存历史数据
        if !result.is_empty() {
            let msg = self.history.get_mut(&id).unwrap();
            msg.push(desc);
            msg.push(result);
            let _ = self.gd.set_data(HISTORY.to_string(), &self.history);
        }

        Ok(())
    }
    fn parser_rsp(info: reqwest::Result<Bytes>) -> Result<Option<BaiduAiRspMsg>> {
        let info = info?;
        let info = String::from_utf8_lossy(info.as_ref());
        if info.trim().is_empty() {
            return Ok(None);
        }
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
        let secret = self
            .secret
            .as_ref()
            .ok_or(anyhow::anyhow!("secret未设置"))?;
        let rsp = self.client
            .post(&format!("https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id={app_id}&client_secret={secret}"))
            .header("Content-Type", "application/json")
            .send().await?;
        let token = rsp.json::<BaiduTokenRsp>().await?;
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

    /// 获取所有的历史数据列表
    fn get_question_list(&self) -> Result<QuestionListMsg> {
        let result: Vec<QuestionMsg> = self
            .history
            .iter()
            .map(|(k, v)| {
                let desc = match v.get(0) {
                    Some(r) => r.trim_start().split_at(8).0.to_string(),
                    None => "".to_string(),
                };
                QuestionMsg { id: *k, desc }
            })
            .collect();
        Ok(QuestionListMsg {
            question_list: result,
        })
    }

    fn get_question(&self, req: Uint32Message) -> Result<VecStringMessage> {
        let result = self
            .history
            .get(&req.value)
            .ok_or(anyhow::anyhow!("无法找到对应id"))?;
        let result = result.into_iter().map(|x| x.to_string()).collect();
        Ok(VecStringMessage { values: result })
    }

    fn new_question(&mut self, req:Uint32Message) -> Result<()> {
        if self.history.contains_key(&req.value) {
            return Err(anyhow::anyhow!("已存在对应的对话id"));
        }
        self.history.insert(req.value, Vec::new());
        Ok(())
    }

    fn del_question(&mut self, req: Uint32Message) -> Result<()> {
        if self.history.remove(&req.value).is_none() {
            return Err(anyhow::anyhow!("不存在对应的对话id"));
        }
        Ok(())
    }
}
