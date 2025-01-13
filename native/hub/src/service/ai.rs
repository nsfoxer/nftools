use crate::common::global_data::GlobalData;
use crate::messages::ai::{
    AiModelMsg, BaiduAiKeyReqMsg, BaiduAiRspMsg, ModelEnum, QuestionListMsg, QuestionMsg,
};
use crate::messages::common::{Uint32Message, VecStringMessage};
use crate::service::service::{Service, ServiceName, StreamService};
use crate::{
    async_func_nono, async_func_notype, async_func_typeno, async_stream_func_typeno, func_end,
    func_notype, func_typeno, func_typetype,
};
use ahash::AHashMap;
use anyhow::{anyhow, Result};
use async_trait::async_trait;
use bytes::Bytes;
use futures_util::StreamExt;
use prost::Message;
use reqwest::Client;
use rinf::debug_print;
use serde::{Deserialize, Serialize};
use std::cmp::PartialEq;
use tokio::sync::mpsc::UnboundedSender;

#[derive(Deserialize)]
struct BaiduAiRsp {
    result: String,
}

#[derive(Deserialize)]
struct SparkAiRsp {
    code: usize,
    choices: Option<Vec<InnerSparkAiRsp>>,
    message: String,
}

#[derive(Deserialize)]
struct InnerSparkAiRsp {
    delta: InnerInnerSparkAiRsp,
}

#[derive(Deserialize)]
struct InnerInnerSparkAiRsp {
    content: String,
}
#[derive(Deserialize)]
struct SparkAiErrorRsp {
    message: String,
}

#[derive(Deserialize)]
struct BaiduAiErrorRsp {
    error_code: usize,
    error_msg: String,
}

const SPARK_LITE_MODEL: &str = "lite";

#[derive(Serialize)]
struct BaiduAiRequest {
    model: Option<&'static str>,
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

#[derive(Serialize, Deserialize, PartialEq, Eq, Clone, Debug, Copy)]
enum AiModelEnum {
    Baidu,
    Spark,
}

const BAIDU_AI: &str = "BaiduAiService";
const APP_ID: &str = "BaiduAiService:APP_ID";
const SECRET: &str = "BaiduAiService:SECRET";
const HISTORY: &str = "BaiduAiService:HISTORY";
const AUTH_TOKEN: &str = "SparkAiService:AUTH_TOKEN";
const MODEL: &str = "AiService:MODEL";
const SPARK_HISTORY: &str = "SparkAiService:HISTORY";

pub struct BaiduAiService {
    client: Client,
    gd: GlobalData,
    token: Option<String>,
    app_id: Option<String>,
    secret: Option<String>,
    // baidu所有的历史数据
    history: AHashMap<u32, Vec<String>>,
    // spark
    auth_token: Option<String>,
    model: AiModelEnum,
}

impl BaiduAiService {
    pub async fn new(gd: GlobalData) -> Self {
        let client = Client::new();
        let model = gd
            .get_data(MODEL.to_string())
            .await
            .unwrap_or(AiModelEnum::Baidu);
        let history = match model {
            AiModelEnum::Baidu => HISTORY,
            AiModelEnum::Spark => SPARK_HISTORY,
        };
        let history = gd
            .get_data(history.to_string())
            .await
            .unwrap_or(AHashMap::new());
        Self {
            client,
            token: None,
            app_id: gd.get_data(APP_ID.to_string()).await,
            secret: gd.get_data(SECRET.to_string()).await,
            auth_token: gd.get_data(AUTH_TOKEN.to_string()).await,
            gd,
            history,
            model,
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
        async_func_typeno!(
            self,
            func,
            req_data,
            set_kv,
            BaiduAiKeyReqMsg,
            set_model,
            AiModelMsg
        );
        func_notype!(self, func, get_question_list, get_model);
        func_typetype!(self, func, req_data, get_question, Uint32Message);
        func_typeno!(
            self,
            func,
            req_data,
            new_question,
            Uint32Message,
            del_question,
            Uint32Message
        );
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
        if self.model == AiModelEnum::Spark && self.auth_token.is_none() {
            return Err(anyhow::anyhow!("请先设置spark的token"));
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
            model: if self.model == AiModelEnum::Spark {
                Some(SPARK_LITE_MODEL)
            } else {
                None
            },
            stream: true,
            messages: msg,
        };
        let request_builder = if self.model == AiModelEnum::Baidu {
            if self.token.is_none() {
                self.refresh_token().await?;
            }
            self.client
                .post(&format!( "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/yi_34b_chat?access_token={}", self.token.as_ref().unwrap()))
        } else {
            self.client
                .post("https://spark-api-open.xf-yun.com/v1/chat/completions")
                .header("Content-Type", "application/json")
                .header("Authorization", self.auth_token.as_ref().unwrap())
        };
        // 60秒超时
        let request_builder =  request_builder.timeout(std::time::Duration::from_millis(60000));

        let mut stream = request_builder.json(&req).send().await?.bytes_stream();

        let mut result = String::new();
        let mut is_error = false;
        while let Some(info) = stream.next().await {
            let data = match Self::parser_rsp(info, self.model.clone()) {
                Ok(data) => {
                    if data.is_none() {
                        continue;
                    }
                    let data = data.unwrap();
                    result.push_str(data.content.as_str());
                    Ok(Some(data.encode_to_vec()))
                }
                Err(e) => {
                    is_error = true;
                    Err(e)
                }
            };
            if let Err(e) = tx.send(data) {
                panic!("发送通道已关闭: {}", e);
            }
        }

        // 保存历史数据
        if is_error {
            // 发生错误不保存信息
            return Ok(());
        }
        if !result.is_empty() {
            let msg = self.history.get_mut(&id).unwrap();
            msg.push(desc);
            msg.push(result);
        }
        let key = if self.model == AiModelEnum::Baidu {
            HISTORY
        } else {
            SPARK_HISTORY
        };
        self.gd.set_data(key.to_string(), &self.history).await?;
        Ok(())
    }
    fn parser_rsp(
        info: reqwest::Result<Bytes>,
        model: AiModelEnum,
    ) -> Result<Option<BaiduAiRspMsg>> {
        let info = info?;
        let info = String::from_utf8_lossy(info.as_ref());
        if info.trim().is_empty() {
            return Ok(None);
        }
        if !info.starts_with("data:") {
            if model == AiModelEnum::Spark {
                let error = serde_json::from_str::<SparkAiErrorRsp>(&info)?;
                return Err(anyhow!(error.message));
            }
            let error = serde_json::from_str::<BaiduAiErrorRsp>(&info)?;
            if error.error_code == 336002 {
                return Err(anyhow::anyhow!("token已失效,请手动刷新token"));
            } else if error.error_code == 110 {
                return Err(anyhow::anyhow!("token错误，请重新设置密钥"));
            } else if error.error_msg.contains("limit") {
                return Err(anyhow::anyhow!("接口调用量超限，请稍后重试"));
            }
            return Err(anyhow::anyhow!(error.error_msg));
        }
        if model == AiModelEnum::Spark {
            if info.trim() == "data: [DONE]" || info.trim().is_empty() {
                return Ok(None);
            }
            debug_print!("{}", info);
            let rsp: SparkAiRsp = serde_json::from_str(
                info.trim()
                    .trim_start_matches("data:")
                    .trim_end_matches("data: [DONE]"),
            )?;
            if rsp.code == 0 && rsp.choices.is_some() {
                let mut sb = String::new();
                for rsp in rsp.choices.unwrap() {
                    sb.push_str(&rsp.delta.content);
                }
                Ok(Some(BaiduAiRspMsg { content: sb }))
            } else {
                Err(anyhow::anyhow!(rsp.message))
            }
        } else {
            let rsp: BaiduAiRsp = serde_json::from_str(info.trim_start_matches("data:"))?;
            Ok(Some(BaiduAiRspMsg {
                content: rsp.result,
            }))
        }
    }
}

impl BaiduAiService {
    /// 刷新token
    async fn refresh_token(&mut self) -> Result<()> {
        if self.model == AiModelEnum::Spark {
            return Err(anyhow::anyhow!("spark模型不支持token刷新"));
        }
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
        if self.model == AiModelEnum::Spark {
            self.auth_token = Some(req.api_key);
            self.gd
                .set_data(AUTH_TOKEN.to_string(), &self.auth_token.as_ref().unwrap())
                .await?;
            return Ok(());
        }

        self.app_id = Some(req.api_key);
        self.secret = Some(req.secret);
        self.refresh_token().await?;
        self.gd
            .set_data(APP_ID.to_string(), &self.app_id.as_ref().unwrap())
            .await?;
        self.gd
            .set_data(SECRET.to_string(), &self.secret.as_ref().unwrap())
            .await?;
        Ok(())
    }

    /// 获取key和secret
    async fn get_kv(&mut self) -> Result<BaiduAiKeyReqMsg> {
        if self.model == AiModelEnum::Spark {
            if self.auth_token.is_none() {
                return Err(anyhow!("需先设置appid"));
            }
            return Ok(BaiduAiKeyReqMsg {
                api_key: self.auth_token.as_ref().unwrap().clone(),
                secret: "".to_string(),
            });
        }
        self.refresh_token().await?;
        Ok(BaiduAiKeyReqMsg {
            api_key: self.app_id.as_ref().unwrap().clone(),
            secret: self.secret.as_ref().unwrap().clone(),
        })
    }

    fn get_model(&self) -> Result<AiModelMsg> {
        let model = match self.model {
            AiModelEnum::Baidu => ModelEnum::Baidu,
            AiModelEnum::Spark => ModelEnum::Spark,
        };
        Ok(AiModelMsg {
            model_enum: i32::from(model),
        })
    }

    async fn set_model(&mut self, model: AiModelMsg) -> Result<()> {
        let model = match ModelEnum::try_from(model.model_enum) {
            Err(_e) => {
                return Err(anyhow::anyhow!("无法获取model"));
            }
            Ok(v) => v,
        };
        let model = match model {
            ModelEnum::Baidu => AiModelEnum::Baidu,
            ModelEnum::Spark => AiModelEnum::Spark,
        };
        if model == self.model {
            return Ok(());
        }
        self.model = model;
        let history = match self.model {
            AiModelEnum::Baidu => HISTORY,
            AiModelEnum::Spark => SPARK_HISTORY,
        };
        self.history = self
            .gd
            .get_data(history.to_string())
            .await
            .unwrap_or(AHashMap::new());
        Ok(())
    }

    /// 获取所有的历史数据列表
    fn get_question_list(&self) -> Result<QuestionListMsg> {
        let result: Vec<QuestionMsg> = self
            .history
            .iter()
            .map(|(k, v)| {
                let desc = match v.get(0) {
                    Some(r) => r.trim_start().chars().take(8).collect(),
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

    fn new_question(&mut self, req: Uint32Message) -> Result<()> {
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

mod test {
    #[test]
    fn string() {
        let s = "本是同根生，相煎何太急";
        let s = s.chars().take(38).collect::<String>();
        eprintln!("{s}");
    }
}
