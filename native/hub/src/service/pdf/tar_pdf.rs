use crate::common::global_data::GlobalData;
use crate::messages::common::{DataMsg, StringMsg, VecStringMsg};
use crate::messages::tar_pdf::{OcrConfigMsg, OcrDataMsg, RefOcrDatasMsg, TarPdfMsg, TarPdfResultMsg, TarPdfResultsMsg};
use crate::service::service::{Service, StreamService};
use crate::{async_func_nono, async_func_notype, async_func_typetype, async_stream_func_typeno, func_end, func_nono, func_notype, func_typeno, func_typetype};
use anyhow::{anyhow, Result};
use futures_util::StreamExt;
use log::debug;
use pdfium::{PdfiumDocument, PdfiumRenderConfig};
use regex::Regex;
use rust_xlsxwriter::{Format, Workbook};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::cmp::Ordering;
use std::collections::HashMap;
use std::io::Cursor;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use ahash::{AHashMap, AHashSet};
use image::DynamicImage;
use strfmt::strfmt;
use tokio::sync::mpsc::UnboundedSender;
use tokio_stream::wrappers::ReadDirStream;
use crate::common::utils::index_to_string;
use crate::service::pdf::ocr::{OcrData, OcrResult};

#[derive(Debug)]
struct PdfResult {
    file_path: PathBuf,
    ocr_result: Result<ExcelData>,
}

#[derive(Debug, Default, Serialize)]
struct ExcelData {
    // 原始文件名称
    file_name: String,
    // 序号
    index: u32,
    // 编号
    no: String,
    // 总页数
    pages: i32,
    // 公司名称
    company_name: String,
    // 标题
    title: String,
}

impl ExcelData {
    // 根据规则转换文件名
    fn convert_file_name(&self, rule: &str) -> Result<String> {
        let json = serde_json::to_value(&self)?;
        let data = if let Value::Object(map) = json {
            map.into_iter()
                .map(|(k, v)| {
                    let null = String::with_capacity(0);
                    if v.is_null() {
                        return (k, null);
                    }
                    let mut v = v.to_string();
                    // 去除字符串的前后引号
                    if v.starts_with('"') && v.ends_with('"'){
                        v.pop();
                        v.remove(0);
                    }
                    if v.is_empty() {
                        (k, null)
                    } else {
                        (k, v)
                    }
                })
                .collect()
        } else {
            HashMap::new()
        };

        Ok(strfmt(rule, &data)?)
    }
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
struct OcrConfig {
    // pdf 密码
    pdf_password: Option<String>,
    // ocr识别url
    url: String,
    // ocr识别密钥
    api_key: String,
    // 编码匹配正则表达式字符串
    no_regex: Vec<String>,
    // 文件名修改规则
    export_file_name_rule: String,
    // 标题匹配正则表达式
    #[serde(skip)]
    no_regex_match: Vec<Regex>,
}

impl OcrConfig {
    /// 是否为有效数据
    fn has_data(&self) -> bool {
        !self.url.is_empty()
            && !self.api_key.is_empty()
            && !self.export_file_name_rule.is_empty()
            && !self.no_regex.is_empty()
            && self.no_regex_match.len() == self.no_regex.len()
    }

    fn ocr_url(&self) -> String {
        format!("{}/ocr", &self.url)
    }
}

impl From<OcrConfigMsg> for OcrConfig {
    fn from(value: OcrConfigMsg) -> Self {
        OcrConfig {
            pdf_password: value.passwd,
            url: value.url,
            api_key: value.api_key,
            no_regex_match: value
                .no_regex
                .iter()
                .map(|x| Regex::new(x))
                .filter_map(|r| r.ok())
                .collect(),
            no_regex: value.no_regex,
            export_file_name_rule: value.export_file_name_rule,
        }
    }
}

impl Into<OcrConfigMsg> for OcrConfig {
    fn into(self) -> OcrConfigMsg {
        OcrConfigMsg {
            passwd: self.pdf_password,
            url: self.url,
            api_key: self.api_key,
            no_regex: self.no_regex,
            export_file_name_rule: self.export_file_name_rule,
        }
    }
}

struct RefData {
    image: DynamicImage,
    // k: tag v: ocr结果
    image_ocr: AHashMap<String, OcrData>,
}

#[derive(Debug, Default)]
struct ExportConfig {
    // 要使用的所有tag
    tags: AHashSet<String>,
    // 模板表达式
    template: String,
}

/// tar pdf服务
pub struct TarPdfService {
    // 数据库配置
    global_data: GlobalData,
    // ocr识别配置
    config: OcrConfig,
    // 参考数据
    ref_data: Option<RefData>,
    // 导出配置
    ref_config: ExportConfig,

}

const CONFIG_CACHE: &str = "tarPdfConfig";

#[async_trait::async_trait]
impl StreamService for TarPdfService {
    async fn handle_stream(
        &mut self,
        func: &str,
        req_data: Vec<u8>,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        // async_stream_func_typeno!(self, func, req_data, handle, StringMsg, tx);
        func_end!(func)
    }
}

#[async_trait::async_trait]
impl Service for TarPdfService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, set_config, OcrConfigMsg, set_ref_config_tags, VecStringMsg);
        func_notype!(self, func, get_config);
        func_typetype!(self, func, req_data, set_ref_config_template, StringMsg);
        async_func_nono!(self, func, ocr_check);
        // async_func_notype!(self, func, export_result_and_rename_files);
        async_func_typetype!(self, func, req_data, scan_pdf, StringMsg, get_pdf_cover, StringMsg, set_ref_config, StringMsg);

        func_end!(func)
    }

    async fn close(&mut self) -> Result<()> {
        if self.config.has_data() {
            self.global_data
                .set_data(CONFIG_CACHE.to_string(), &self.config)
                .await?;
        }
        Ok(())
    }
}

impl TarPdfService {
    fn set_config(&mut self, config: OcrConfigMsg) -> Result<()> {
        for regex in &config.no_regex {
            if let Err(e) = Regex::new(regex) {
                return Err(anyhow!("正则表达式错误：{}", e));
            }
        }
        let excel_data = ExcelData::default();
        if let Err(e) = excel_data.convert_file_name(&config.export_file_name_rule) {
            return Err(anyhow!("文件名规则错误：{}", e));
        }

        let config = OcrConfig::from(config);
        if !config.has_data() {
            Err(anyhow!("配置不正确"))
        } else {
            self.config = config;
            Ok(())
        }
    }

    fn get_config(&self) -> Result<OcrConfigMsg> {
        if self.config.has_data() {
            Ok(self.config.clone().into())
        } else {
            Err(anyhow!("请先设置OCR配置"))
        }
    }

    const ERROR_MSG: &'static str = "无法探测出OCR服务器，请检查配置";
    async fn ocr_check(&self) -> Result<()> {
        if !self.config.has_data() {
            return Err(anyhow!("请先设置OCR配置"));
        }

        let url = format!("{}/check", &self.config.url);
        let rsp = reqwest::Client::new()
            .post(url)
            .header("api-key", &self.config.api_key)
            .send()
            .await?
            .text()
            .await?;
        let rsp: Value = serde_json::from_str(&rsp)?;
        let r = rsp.get("result").ok_or_else(|| anyhow!(Self::ERROR_MSG))?;
        let r = r.as_str().ok_or_else(|| anyhow!(Self::ERROR_MSG))?;
        if r != "pass" {
            return Err(anyhow!(Self::ERROR_MSG));
        }
        Ok(())
    }

    // async fn handle(
    //     &mut self,
    //     pdf_dir: StringMsg,
    //     tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    // ) -> Result<()> {
    //     self.ocr_check().await?;
    //
    //     let pdf_dir = PathBuf::from(pdf_dir.value);
    //     if !pdf_dir.exists() || !pdf_dir.is_dir() {
    //         return Err(anyhow!("pdf目录不存在或非目录"));
    //     }
    //
    //     self.result.clear();
    //
    //     // 按创建时间从最新到最旧遍历所有后缀为pdf的文件
    //     let mut pdf_files = get_pdf_files_in_directory(&pdf_dir).await?;
    //     pdf_files.sort();
    //
    //     // handle
    //     let url = format!("{}/ocr", &self.config.url);
    //     let count = pdf_files.len();
    //     for (index, pdf_file) in pdf_files.into_iter().enumerate() {
    //         // send current process
    //         let file_name = pdf_file
    //             .path
    //             .file_name()
    //             .unwrap_or_default()
    //             .to_str()
    //             .unwrap_or_default()
    //             .to_string();
    //         let msg = rinf::serialize(&TarPdfMsg {
    //             now: (index+1) as u32,
    //             sum: count as u32,
    //             current_file: file_name,
    //         });
    //         tx.send(Ok(Some(msg?)))?;
    //
    //         // 处理OCR
    //         let ocr = self
    //             .ocr_pdf(pdf_file.path.clone(), index as u32, &url)
    //             .await;
    //
    //         // 保存结果
    //         let r = PdfResult {
    //             file_path: pdf_file.path,
    //             ocr_result: ocr,
    //         };
    //         self.result.push(r);
    //     }
    //
    //     Ok(())
    // }

    // fn get_result(&self) -> Result<TarPdfResultsMsg> {
    //     let data = self
    //         .result
    //         .iter()
    //         .map(|x| {
    //             let file_name = x
    //                 .file_path
    //                 .file_name()
    //                 .unwrap()
    //                 .to_str()
    //                 .unwrap()
    //                 .to_string();
    //             let mut ocr_result = TarPdfResultMsg::default();
    //             ocr_result.file_name = file_name;
    //             match &x.ocr_result {
    //                 Ok(r) => {
    //                     ocr_result.company = r.company_name.clone();
    //                     ocr_result.title = r.title.clone();
    //                     ocr_result.no = r.no.clone();
    //                     ocr_result.error_msg = String::with_capacity(0);
    //                     ocr_result.pages = r.pages;
    //                 }
    //                 Err(e) => {
    //                     ocr_result.error_msg = e.to_string();
    //                 }
    //             };
    //             ocr_result
    //         })
    //         .collect();
    //     Ok(TarPdfResultsMsg { datas: data })
    // }

    /// 导出结果并重命名文件
    /// return 导出后的文件
    // async fn export_result_and_rename_files(&mut self) -> Result<StringMsg> {
    //     if self.result.is_empty() {
    //         return Err(anyhow!("无识别结果"));
    //     }
    //
    //     // 1. 重命名文件
    //     for pdf in self.result.iter_mut() {
    //         if let Err(e) = Self::rename_pdf(pdf, &self.config.export_file_name_rule).await {
    //             pdf.ocr_result = Err(e);
    //         }
    //     }
    //
    //     // 2. 导出excel表格
    //     let file = self.write_excel_file().await?;
    //     let name = file
    //         .file_name()
    //         .unwrap_or_default()
    //         .to_str()
    //         .unwrap_or_default()
    //         .to_string();
    //     Ok(StringMsg { value: name })
    // }

    /// 清除识别结果
    // fn clear_result(&mut self) -> Result<()> {
    //     self.result.clear();
    //     Ok(())
    // }

    /// 扫描指定文件夹下的文件
    ///
    /// `pdf_dir`: 要扫描的目录
    ///
    /// `return`: 扫描结果(绝对路径)
    async fn scan_pdf(&self, pdf_dir: StringMsg) -> Result<VecStringMsg> {
        let pdf_dir = PathBuf::from(pdf_dir.value);
        if !pdf_dir.exists() || !pdf_dir.is_dir() {
            return Err(anyhow!("pdf目录不存在或非目录"));
        }
        let pdf_files = get_pdf_files_in_directory(&pdf_dir).await?;
        Ok(VecStringMsg {
            values: pdf_files.into_iter().map(|x| x.path.into_os_string().into_string().unwrap()).collect()
        })
    }

    /// 获取pdf封面
    async fn get_pdf_cover(&self, pdf_file: StringMsg) -> Result<DataMsg> {
        if !self.config.has_data() {
            return Err(anyhow!("请先设置OCR配置"));
        }
        let pdf = PathBuf::from(pdf_file.value);
        if !pdf.exists() || !pdf.is_file() {
            return Err(anyhow!("pdf文件不存在或非文件"));
        }
        let pdf_password = self.config.pdf_password.clone();
        let (img, _pages) = tokio::task::spawn_blocking(move || {
            export_pdf_to_jpegs(&pdf, pdf_password.as_deref())
        }).await??;
        Ok(DataMsg{
            value: img_to_buf(&img)?,
        })
    }

    /// 设置参考文件
    async fn set_ref_config(&mut self, ref_image_file: StringMsg) -> Result<RefOcrDatasMsg> {
        // 1. 基本检查
        if !self.config.has_data() {
            return Err(anyhow!("请先设置OCR配置"));
        }
        let pdf = PathBuf::from(ref_image_file.value);
        if !pdf.exists() || !pdf.is_file() {
            return Err(anyhow!("pdf文件不存在或非文件"));
        }

        // 2. 识别数据
        let (img, _pages, ocr_result) = self.ocr_pdf(pdf, &self.config.ocr_url()).await?;
        let data = ocr_result.result.into_ocr_data();

        // 3. 转换数据
        let result = RefOcrDatasMsg {
            data: data.iter().enumerate().map(|(i, x)| {
                OcrDataMsg {
                    id: index_to_string(i),
                    text: x.text.clone(),
                    location: x.location.clone().into(),
                }
            }).collect()
        };

        let data: AHashMap<String, OcrData> = data.into_iter().enumerate().map(|(i, x)| {
            (index_to_string(i), x)
        }).collect();
        self.ref_data = Some(RefData {
            image: img,
            image_ocr: data,
        });
        Ok(result)
    }

    /// 设置参考tags
    fn set_ref_config_tags(&mut self, tags: VecStringMsg) -> Result<()> {
        self.ref_config.tags.clear();
        for data in tags.values {
            self.ref_config.tags.insert(data);
        }
        Ok(())
    }

    /// 设置模板
    fn set_ref_config_template(&mut self, template: StringMsg) -> Result<StringMsg> {
        if self.ref_config.tags.is_empty() {
            return Err(anyhow!("请先设置参考tags"));
        }
        if self.ref_data.is_none() {
            return Err(anyhow!("请先设置参考文件"));
        }

        let mut data_map = HashMap::new();
        for (tag, data) in &self.ref_data.as_ref().unwrap().image_ocr {
            data_map.insert(tag.clone(), data.text.as_str());
        }
        let result =  strfmt(&template.value, &data_map)?;
        Ok(StringMsg{
            value: result,
        })
    }
}

impl TarPdfService {
    pub async fn new(global_data: GlobalData) -> Self {
        let mut config: OcrConfig = global_data
            .get_data(CONFIG_CACHE.to_string())
            .await
            .unwrap_or_default();
        config.no_regex_match = config
            .no_regex
            .iter()
            .map(|x| Regex::new(x))
            .filter_map(|r| r.ok())
            .collect();
        TarPdfService {
            global_data,
            config,
            ref_data: None,
            ref_config: Default::default(),
        }
    }

    /// ocr_pdf
    async fn ocr_pdf(&self, pdf_file: PathBuf, url: &str) -> Result<(DynamicImage, usize, OcrResult)> {
        // 1. 文本识别
        let pdf_password = self.config.pdf_password.clone();
        let (img, pages) = tokio::task::spawn_blocking(move || {
            export_pdf_to_jpegs(&pdf_file, pdf_password.as_deref())
        })
        .await??;
        let part = reqwest::multipart::Part::bytes(img_to_buf(&img)?).file_name("t.jpeg");
        let form = reqwest::multipart::Form::new()
            .part("file", part);
        let result = reqwest::Client::new()
            .post(url)
            .header("api-key", &self.config.api_key)
            .multipart(form)
            .send()
            .await?;
        let text = result.text().await?;
        let mut ocr_result: OcrResult = serde_json::from_str(&text)?;

        // 2. 识别数据
        ocr_result.clear_fuzzy_data();

        Ok((img, pages as usize, ocr_result))
    }

    // 重命名文件
    async fn rename_pdf(pdf: &PdfResult, rule: &str) -> Result<()> {
        // 1. 生成文件名
        if let Err(e) = &pdf.ocr_result {
            return Err(anyhow!("{}", e.to_string()));
        }
        let pdf_result = pdf.ocr_result.as_ref().unwrap();
        let file_name = pdf_result.convert_file_name(rule)?;

        // 2. 重命名
        let mut file = pdf.file_path.clone();
        file.pop();
        file.push(&file_name);
        if file.exists() {
            return Err(anyhow!("无法重命名【{}】文件已存在", &file_name));
        }
        tokio::fs::rename(&pdf.file_path, &file).await?;

        Ok(())
    }

    // async fn write_excel_file(&self) -> Result<PathBuf> {
    //     if self.result.is_empty() {
    //         return Err(anyhow!("无识别结果"));
    //     }
    //     // 1. 创建文件
    //     let mut file = self.result.get(0).unwrap().file_path.clone();
    //     file.pop();
    //     let now = SystemTime::now();
    //     file.push(format!(
    //         "检测报告识别结果_{}.xlsx",
    //         now.duration_since(UNIX_EPOCH)?.as_millis()
    //     ));
    //
    //     // 2. 写入数据
    //     let mut workbook = Workbook::new();
    //     let worksheet = workbook.add_worksheet().set_name("sheet1")?;
    //     // 定义一些单元格样式
    //     let header_format = Format::new()
    //         .set_bold()
    //         .set_background_color(rust_xlsxwriter::Color::RGB(0xD9E1F2))
    //         .set_border(rust_xlsxwriter::FormatBorder::Thin);
    //     let error_format =
    //         Format::new().set_background_color(rust_xlsxwriter::Color::RGB(0xFFC7CE));
    //     let number_format = Format::new().set_num_format("0");
    //
    //     // 创建表头
    //     worksheet.write_with_format(0, 0, "原始文件", &header_format)?;
    //     worksheet.write_with_format(0, 1, "序号", &header_format)?;
    //     worksheet.write_with_format(0, 2, "文件名称", &header_format)?;
    //     worksheet.write_with_format(0, 3, "文件编号", &header_format)?;
    //     worksheet.write_with_format(0, 4, "页数", &header_format)?;
    //     worksheet.write_with_format(0, 5, "错误信息", &header_format)?;
    //
    //     // 创建数据行
    //     for (index, pdf) in self.result.iter().enumerate() {
    //         let row = (index + 1) as u32;
    //         worksheet.write(
    //             row,
    //             0,
    //             pdf.file_path
    //                 .file_name()
    //                 .unwrap_or_default()
    //                 .to_str()
    //                 .unwrap_or_default(),
    //         )?;
    //         worksheet.write_number_with_format(row, 1, (index + 1) as f64, &number_format)?;
    //         match &pdf.ocr_result {
    //             Ok(data) => {
    //                 worksheet.write(row, 2, format!("{}{}", data.company_name, data.title))?;
    //                 worksheet.write(row, 3, &data.no)?;
    //                 worksheet.write_number_with_format(
    //                     row,
    //                     4,
    //                     data.pages as f64,
    //                     &number_format,
    //                 )?;
    //             }
    //             Err(e) => {
    //                 worksheet.write_with_format(row, 5, e.to_string(), &error_format)?;
    //             }
    //         };
    //     }
    //
    //     // 3. 保存文件
    //     workbook.save(&file)?;
    //
    //     Ok(file)
    // }
}

// 存储文件路径和创建时间的结构体
#[derive(Debug)]
struct PdfFile {
    path: PathBuf,
    created_time: SystemTime,
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


// 非递归获取指定目录中的所有PDF文件
async fn get_pdf_files_in_directory(dir: &Path) -> Result<Vec<PdfFile>> {
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
                        pdf_files.push(PdfFile { path, created_time });
                    }
                }
            }
        }
    }

    Ok(pdf_files)
}

fn export_pdf_to_jpegs(path: &Path, password: Option<&str>) -> Result<(DynamicImage, i32)> {
    let pdf = PdfiumDocument::new_from_path(path, password)?;
    let page = pdf.page(0)?;
    let config = PdfiumRenderConfig::new().with_width(861);
    let bitmap = page.render(&config)?;
    let img = bitmap.as_rgb8_image()?;
    Ok((img, pdf.page_count()))
}

fn img_to_buf(img: &DynamicImage) -> Result<Vec<u8>> {
    let mut buf= Cursor::new(Vec::new());
    img.write_to(&mut buf, image::ImageFormat::Jpeg)?;
    Ok(buf.into_inner())
}

mod test {
    use crate::service::pdf::tar_pdf::{export_pdf_to_jpegs, ExcelData};



    #[test]
    fn test2() {
        let excel = ExcelData::default();
        let rule = r#"{index}{no}{company_name}{title}-xxx.xlsx"#;
        let r = excel.convert_file_name(rule).unwrap();
        assert_eq!("0-xxx.xlsx", r);
    }
}
