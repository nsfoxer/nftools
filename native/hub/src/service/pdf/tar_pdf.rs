use std::cmp::Ordering;
use crate::messages::common::StringMsg;
use crate::service::service::{Service, StreamService};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc::UnboundedSender;
use anyhow::{anyhow, Result};
use futures_util::StreamExt;
use pdfium::{PdfiumDocument, PdfiumRenderConfig};
use serde::Deserialize;
use tempfile::NamedTempFile;
use tokio_stream::wrappers::ReadDirStream;
use crate::{async_stream_func_typeno, func_end};
use crate::messages::tar_pdf::TarPdfMsg;

/// tar pdf服务
pub struct TarPdfService {
}

#[async_trait::async_trait]
impl StreamService for TarPdfService {
    async fn handle_stream(
        &mut self,
        func: &str,
        req_data: Vec<u8>,
        tx: UnboundedSender<anyhow::Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        async_stream_func_typeno!(self, func, req_data, start, StringMsg, tx);
        func_end!(func)
    }
}

#[async_trait::async_trait]
impl Service for TarPdfService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> anyhow::Result<Option<Vec<u8>>> {
        func_end!(func)
    }
}

impl TarPdfService {
    pub async fn start(&mut self, pdf_dir: StringMsg, tx: UnboundedSender<Result<Option<Vec<u8>>>>) -> Result<()> {
        let pdf_dir = PathBuf::from(pdf_dir.value);
        if !pdf_dir.exists() {
            return Err(anyhow!("pdf_dir not exists"));
        }
        if !pdf_dir.is_dir() {
            return Err(anyhow!("pdf_dir is not a directory"));
        }

        // 按创建时间从最新到最旧遍历所有后缀为pdf的文件
        let mut pdf_files = get_pdf_files_in_directory(&pdf_dir).await?;
        pdf_files.sort();

        // handle
        let count = pdf_files.len();
        for (index, pdf_file) in pdf_files.into_iter().enumerate() {
            let file_name = pdf_file.path.file_name().unwrap_or_default().to_str().unwrap_or_default().to_string();
            let msg = match ocr_pdf(pdf_file.path).await {
                Ok(r) => TarPdfMsg {
                    now: (index + 1) as u32,
                    sum: count as u32,
                    current_file: file_name,
                },
                Err(e) => TarPdfMsg {
                    now: (index + 1) as u32,
                    sum: count as u32,
                    current_file: file_name,
                },
            };
            let msg = rinf::serialize(&msg);
            tx.send(Ok(Some(msg?)))?;
        }

        Ok(())
    }
}

impl TarPdfService {
    pub fn new() -> Self {
        TarPdfService {
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

async fn ocr_pdf(pdf_file: PathBuf) -> Result<Vec<String>> {
    let img = tokio::task::spawn_blocking(move || {
        export_pdf_to_jpegs(&pdf_file, None)
    }).await??;
    let form = reqwest::multipart::Form::new()
        .file("file", img).await?;
    let result = reqwest::Client::new()
        .post("")
        .header("", "")
        .multipart(form)
        .send()
        .await?
        .json::<OcrResult>()
        .await?;

    Ok(result.result.texts)
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

mod test {
    use std::path::PathBuf;
    use crate::service::pdf::tar_pdf::ocr_pdf;

    #[tokio::test]
    async fn ocr() {
        let pdf = PathBuf::from("/home/nsfoxer/桌面/关于2023年淮安市市本级监测及质控服务项目的工作总结 （第四版）.pdf");
        let r = ocr_pdf(pdf).await.unwrap();
        eprintln!("{:?}", r);
    }
}