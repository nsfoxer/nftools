use std::cmp::Ordering;
use crate::messages::common::StringMsg;
use crate::service::service::{Service, StreamService};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc::UnboundedSender;
use anyhow::{anyhow, Result};
use futures_util::StreamExt;
use log::debug;
use pdfium::{PdfiumDocument, PdfiumRenderConfig};
use serde::Deserialize;
use serde_json::{json, Value};
use tempfile::NamedTempFile;
use tokio_stream::wrappers::ReadDirStream;
use regex::Regex;
use crate::{async_func_nono, async_stream_func_typeno, func_end, func_notype, func_typeno};
use crate::common::global_data::GlobalData;
use crate::messages::tar_pdf::{TarPdfMsg, TarPdfResultMsg, TarPdfResultsMsg};

#[derive(Debug)]
struct PdfResult {
    file_path: PathBuf,
    ocr_result: Result<String>,
}

/// tar pdf服务
pub struct TarPdfService {
    global_data: GlobalData,
    pdf_password: Option<String>,
    url: Option<String>,
    url_key: Option<String>,
    result: Vec<PdfResult>,
}

const URL_CACHE: &str = "tarPdfPrefix-url";
const URL_KEY_CACHE: &str = "tarPdfPrefix-url_key";

#[async_trait::async_trait]
impl StreamService for TarPdfService {
    async fn handle_stream(
        &mut self,
        func: &str,
        req_data: Vec<u8>,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        async_stream_func_typeno!(self, func, req_data, start, StringMsg, tx);
        func_end!(func)
    }
}

#[async_trait::async_trait]
impl Service for TarPdfService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, set_url, StringMsg, set_password, StringMsg, set_url_key, StringMsg);
        func_notype!(self, func, get_url, get_url_key, get_password, get_result);
        async_func_nono!(self, func, ocr_check);

        func_end!(func)
    }

    async fn close(&mut self) -> Result<()> {
        if let Some(k) = &self.url {
            self.global_data.set_data(URL_CACHE.to_string(), k).await?;
        }
        if let Some(k) = &self.url_key {
            self.global_data.set_data(URL_KEY_CACHE.to_string(), k).await?;
        }

        Ok(())
    }
}

impl TarPdfService {

    fn set_url(&mut self, url: StringMsg) -> Result<()> {
        let mut ourl = url.value;
        let url = ourl.trim();
        if !url.starts_with("http://") && !url.starts_with("https://") {
            return Err(anyhow!("url必须以http://或https://开头"));
        }
        if url.ends_with("/") {
            ourl.pop();
        }
        self.url = Some(ourl);
        Ok(())
    }

    fn get_url(&self) -> Result<StringMsg> {
        Ok(StringMsg {
            value: self.url.clone().unwrap_or(String::with_capacity(0)),
        })
    }

    fn set_password(&mut self, password: StringMsg) -> Result<()> {
        self.pdf_password = Some(password.value);
        Ok(())
    }
    fn get_password(&self) -> Result<StringMsg> {
        Ok(StringMsg {
            value: self.pdf_password.clone().unwrap_or(String::with_capacity(0)),
        })
    }

    fn set_url_key(&mut self, url_key: StringMsg) -> Result<()> {
        self.url_key = Some(url_key.value);
        Ok(())
    }

    fn get_url_key(&self) -> Result<StringMsg> {
        Ok(StringMsg {
            value: self.url_key.clone().unwrap_or(String::with_capacity(0)),
        })
    }

    const ERROR_MSG: &'static str = "无法探测出OCR服务器，请检查配置";
    async fn ocr_check(&self) -> Result<()> {
        self.check_config()?;
        let url = format!("{}/check", self.url.as_ref().unwrap());
        let rsp = reqwest::Client::new()
            .post(url)
            .header("api-key", self.url_key.as_ref().unwrap())
            .send()
            .await?
            .text()
            .await?;
        let rsp: Value = serde_json::from_str(&rsp)?;
        debug!("ocr check result: {}", rsp);
        let r = rsp.get("result").ok_or_else(|| anyhow!(Self::ERROR_MSG))?;
        let r = r.as_str().ok_or_else(|| anyhow!(Self::ERROR_MSG))?;
        if r != "pass" {
           return Err(anyhow!(Self::ERROR_MSG));
        }
        Ok(())
    }
    
    
    async fn start(&mut self, pdf_dir: StringMsg, tx: UnboundedSender<Result<Option<Vec<u8>>>>) -> Result<()> {
        self.ocr_check().await?;

        let pdf_dir = PathBuf::from(pdf_dir.value);
        if !pdf_dir.exists() {
            return Err(anyhow!("pdf_dir not exists"));
        }
        if !pdf_dir.is_dir() {
            return Err(anyhow!("pdf_dir is not a directory"));
        }
        self.result.clear();

        // 按创建时间从最新到最旧遍历所有后缀为pdf的文件
        let mut pdf_files = get_pdf_files_in_directory(&pdf_dir).await?;
        pdf_files.sort();

        // handle
        let url = format!("{}/ocr", self.url.as_ref().unwrap());
        let count = pdf_files.len();
        for (index, pdf_file) in pdf_files.into_iter().enumerate() {
            let file_name = pdf_file.path.file_name().unwrap_or_default().to_str().unwrap_or_default().to_string();
            let ocr = ocr_pdf(pdf_file.path.clone(), self.url.as_ref().unwrap(), &url, &self.pdf_password).await;
            let msg = rinf::serialize(&TarPdfMsg {
                now: index as u32,
                sum: count as u32,
                current_file: file_name,
            });
            tx.send(Ok(Some(msg?)))?;
            let r = PdfResult {
                file_path: pdf_file.path,
                ocr_result: ocr,
            };
            self.result.push(r);
        }

        Ok(())
    }

    fn get_result(&self) -> Result<TarPdfResultsMsg> {
        let data = self.result.iter().map(|x| {
            let file_name = x.file_path.file_name().unwrap().to_str().unwrap().to_string();
            match &x.ocr_result {
                Ok(r) => TarPdfResultMsg {
                    file_name,
                    title: r.clone(),
                    error_msg: String::with_capacity(0),
                },
                Err(e) => TarPdfResultMsg {
                    file_name,
                    title: String::with_capacity(0),
                    error_msg: e.to_string(),
                }
            }
        }).collect();
        Ok(TarPdfResultsMsg{
            datas: data,
        })
    }

    fn check_config(&self) -> Result<()>{
        if self.url.is_none() {
            return Err(anyhow!("url is empty"));
        }
        if self.url_key.is_none() {
            return Err(anyhow!("url_key is empty"));
        }
        Ok(())
    }
}

impl TarPdfService {
    pub async fn new(global_data: GlobalData) -> Self {
        let url = global_data.get_data(URL_CACHE.to_string()).await;
        let url_key = global_data.get_data(URL_KEY_CACHE.to_string()).await;
        TarPdfService {
            global_data,
            url,
            url_key,
            pdf_password: None,
            result: Vec::new(),
        }
    }
}

// 存储文件路径和创建时间的结构体
#[derive(Debug)]
struct PdfFile {
    path: PathBuf,
    created_time: std::time::SystemTime,
}

impl Ord for PdfFile {
    // 按创建时间从新到旧排序（逆序）
    fn cmp(&self, other: &Self) -> Ordering {
        other.created_time.cmp(&self.created_time)
    }
}

impl PartialOrd for PdfFile {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl PartialEq for PdfFile {
    fn eq(&self, other: &Self) -> bool {
       self.created_time == other.created_time
    }
}

impl Eq for PdfFile {}

#[derive(Debug, Deserialize)]
struct OcrResult {
    result: OcrTexts
}
#[derive(Debug, Deserialize)]
struct OcrTexts{
    texts: Vec<String>,
}

// 非递归获取指定目录中的所有PDF文件
async fn get_pdf_files_in_directory(
    dir: &Path,
) -> Result<Vec<PdfFile>> {
    let mut pdf_files = Vec::new();

    if !dir.is_dir() {
        return Ok(pdf_files);
    }

    // 异步读取目录
    let dir = tokio::fs::read_dir(dir).await?;
    let mut entries = ReadDirStream::new(dir);

    // 使用异步流的方式遍历目录项
    while let Some(entry) = entries.next().await {
        let entry = entry?;
        let path = entry.path();
        let metadata = entry.metadata().await?;

        // 只处理文件，不递归处理子目录
        if metadata.is_file() {
            // 检查文件扩展名是否为PDF
            if let Some(ext) = path.extension() {
                if ext.eq_ignore_ascii_case("pdf") {
                    // 获取创建时间
                    if let Ok(created_time) = metadata.created() {
                        pdf_files.push(PdfFile {
                            path,
                            created_time,
                        });
                    }
                }
            }
        }
    }

    Ok(pdf_files)
}

async fn ocr_pdf(pdf_file: PathBuf, url: &str, url_key: &str, pdf_password: &Option<String>) -> Result<String> {
    // 1. 文本识别
    let pdf_password = pdf_password.clone();
    let img = tokio::task::spawn_blocking(move || {
        export_pdf_to_jpegs(&pdf_file, pdf_password.as_deref())
    }).await??;
    let form = reqwest::multipart::Form::new()
        .file("file", img).await?;
    let result = reqwest::Client::new()
        .post(url)
        .header("api-key", url_key)
        .multipart(form)
        .send()
        .await?
        .json::<OcrResult>()
        .await?;

    // 2. 识别标题
    let pattern = r#"[\(|（]\d{4}[\)|）].*[\(|（].*[\)|）].*[\(|（].*[)|）].*"#;
    let re = Regex::new(pattern)?;
    let mut titles = Vec::new();
    for text in result.result.texts.iter() {
        if re.is_match(&text.trim()) {
            titles.push(text.trim());
        }
    }
    if titles.is_empty() {
        return Err(anyhow!("未成功识别"));
    }
    if titles.len() > 1 {
        return Err(anyhow!("识别到多个标题"));
    }


    Ok(titles.get(0).unwrap().to_string())
}

fn export_pdf_to_jpegs(path: &Path, password: Option<&str>) -> Result<NamedTempFile> {
    let pdf = PdfiumDocument::new_from_path(path, password)?;
    let page = pdf.page(2)?;
    let config = PdfiumRenderConfig::new().with_width(1920);
    let bitmap = page.render(&config)?;
    let tmp_file = NamedTempFile::with_suffix("png")?;
    bitmap.save(tmp_file.path().to_str().unwrap(), image::ImageFormat::Jpeg)?;
    Ok(tmp_file)
}