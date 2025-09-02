use serde_with::DisplayFromStr;
use serde_with::{serde_as, SerializeDisplay};
use std::cmp::Ordering;
use crate::messages::common::StringMsg;
use crate::service::service::{Service, StreamService};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc::UnboundedSender;
use anyhow::{anyhow, Result};
use futures_util::StreamExt;
use log::debug;
use pdfium::{PdfiumDocument, PdfiumRenderConfig};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tempfile::NamedTempFile;
use tokio_stream::wrappers::ReadDirStream;
use regex::Regex;
use crate::{async_func_nono, async_stream_func_typeno, func_end, func_notype, func_typeno};
use crate::common::global_data::GlobalData;
use crate::messages::tar_pdf::{OcrConfigMsg, TarPdfMsg, TarPdfResultMsg, TarPdfResultsMsg};

#[derive(Debug)]
struct PdfResult {
    file_path: PathBuf,
    ocr_result: Result<ExcelData>,
}

#[derive(Debug)]
struct ExcelData {
    // 原始文件名称
    file_path: String,
    // 编号
    no: String,
    // 总页数
    pages: i32,
    // 公司名称
    company_name: String,
    // 标题
    title: String
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

    // 标题匹配正则表达式
    #[serde(skip)]
    no_regex_match: Vec<Regex>,
}

impl OcrConfig {
    /// 是否为有效数据
    fn has_data(&self) -> bool {
        !self.url.is_empty() && !self.api_key.is_empty() && !self.no_regex.is_empty()
            && self.no_regex_match.len() == self.no_regex.len()
    }
}

impl From<OcrConfigMsg> for OcrConfig {
    fn from(value: OcrConfigMsg) -> Self {
        OcrConfig {
            pdf_password: value.passwd,
            url: value.url,
            api_key: value.api_key,
            no_regex_match: value.no_regex.iter().map(|x| Regex::new(x)).filter_map(|r| r.ok()).collect(),
            no_regex: value.no_regex,
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
        }
    }
}

/// tar pdf服务
pub struct TarPdfService {
    global_data: GlobalData,
    config: OcrConfig,
    result: Vec<PdfResult>,
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
        async_stream_func_typeno!(self, func, req_data, handle, StringMsg, tx);
        func_end!(func)
    }
}

#[async_trait::async_trait]
impl Service for TarPdfService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, set_config, OcrConfigMsg);
        func_notype!(self, func, get_config);
        async_func_nono!(self, func, ocr_check);

        func_end!(func)
    }

    async fn close(&mut self) -> Result<()> {
        if self.config.has_data() {
            self.global_data.set_data(CONFIG_CACHE.to_string(), &self.config).await?;
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

    async fn handle(&mut self, pdf_dir: StringMsg, tx: UnboundedSender<Result<Option<Vec<u8>>>>) -> Result<()> {
        self.ocr_check().await?;

        let pdf_dir = PathBuf::from(pdf_dir.value);
        if !pdf_dir.exists() || !pdf_dir.is_dir() {
            return Err(anyhow!("pdf目录不存在或非目录"));
        }

        self.result.clear();

        // 按创建时间从最新到最旧遍历所有后缀为pdf的文件
        let mut pdf_files = get_pdf_files_in_directory(&pdf_dir).await?;
        pdf_files.sort();

        // handle
        let url = format!("{}/ocr", &self.config.url);
        let count = pdf_files.len();
        for (index, pdf_file) in pdf_files.into_iter().enumerate() {
            // send current process
            let file_name = pdf_file.path.file_name().unwrap_or_default().to_str().unwrap_or_default().to_string();
            let msg = rinf::serialize(&TarPdfMsg {
                now: index as u32,
                sum: count as u32,
                current_file: file_name,
            });
            tx.send(Ok(Some(msg?)))?;

            // 处理OCR
            let ocr = self.ocr_pdf(pdf_file.path.clone(), &url).await;

            // 保存结果
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
            let mut ocr_result = TarPdfResultMsg::default();
            ocr_result.file_name = file_name;
            match &x.ocr_result {
                Ok(r) => {
                    ocr_result.company = r.company_name.clone();
                    ocr_result.title = r.title.clone();
                    ocr_result.no = r.no.clone();
                    ocr_result.error_msg = String::with_capacity(0);
                    ocr_result.pages =  r.pages;
                },
                Err(e) => {
                   ocr_result.error_msg = e.to_string();
                }
            };
            ocr_result
        }).collect();
        Ok(TarPdfResultsMsg{
            datas: data,
        })
    }

}

impl TarPdfService {
    pub async fn new(global_data: GlobalData) -> Self {
        let config = global_data.get_data(CONFIG_CACHE.to_string()).await.unwrap_or_default();
        TarPdfService {
            global_data,
            config,
            result: Vec::new(),
        }
    }

    // ocr_pdf
    async fn ocr_pdf(&self, pdf_file: PathBuf, url: &str) -> Result<ExcelData> {
        // 1. 文本识别
        let pdf_path = pdf_file.to_str().unwrap().to_string();
        let pdf_password = self.config.pdf_password.clone();
        let (img, pages) = tokio::task::spawn_blocking(move || {
            export_pdf_to_jpegs(&pdf_file, pdf_password.as_deref())
        }).await??;
        let form = reqwest::multipart::Form::new()
            .file("file", img).await?;
        let result = reqwest::Client::new()
            .post(url)
            .header("api-key", &self.config.api_key)
            .multipart(form)
            .send()
            .await?;
        let text = result.text().await?;
        debug!("ocr url response: {}", text);
        let ocr_result: OcrResult = serde_json::from_str(&text)?;

        // 2. 识别数据
        // a. 识别编号
        let no = ocr_result.get_no(&self.config.no_regex_match)?;
        // b. 识别公司名称
        let company = ocr_result.get_company_name()?;
        // c. 识别标题
        let title = ocr_result.get_title()?;

        Ok(ExcelData {
            file_path: pdf_path,
            no,
            pages,
            company_name: company,
            title
        })
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
    result: OcrTexts,
}
#[serde_as]
#[derive(Debug, Deserialize)]
struct OcrTexts{
    texts: Vec<String>,
    #[serde_as(as = "Vec<DisplayFromStr>")]
    scores: Vec<f64>,
    boxes: Vec<BoxPosition>,
}
#[serde_as]
#[derive(Debug, Deserialize)]
struct BoxPosition {
    #[serde_as(as = "DisplayFromStr")]
    x: f64,
    #[serde_as(as = "DisplayFromStr")]
    y: f64,
    #[serde_as(as = "DisplayFromStr")]
    width: f64,
    #[serde_as(as = "DisplayFromStr")]
    height: f64,
}

struct FontFeature {
    width: f64,
    height: f64,
    y: f64,
}

impl FontFeature {
    // 字体大小相似
    fn font_similar(&self, other: &Self) -> bool {
        (self.width - other.width).abs() / self.width < 0.05 &&
            (self.height - other.height).abs() / self.height < 0.05
    }

    // 高度接近(上下行排列)
    fn height_nearest(&self, other: &Self) -> bool {
        (self.y - other.y).abs() / self.height < 2.3 &&
            (self.y - other.y).abs() / self.height > 1.0
    }

    // 同行数据
    fn same_line(&self, other: &Self) -> bool {
        (self.y - other.y).abs() / self.height < 0.5
    }
}

impl OcrTexts {
    pub fn clear_fuzzy_data(&mut self) {
        let mut locations = Vec::new();
        for (i, scores) in self.scores.iter().enumerate() {
            if *scores < 0.98 {
                locations.push(i);
            }
        }
        // 删除坐标在locations之内的数据
        for i in locations.iter().rev() {
            self.texts.remove(*i);
            self.scores.remove(*i);
            self.boxes.remove(*i);
        }
    }

    // 获取附近的文本
    fn operate_text(&self, index: usize, result: &mut Vec<usize>, func: fn(&FontFeature, &FontFeature) -> bool) -> Result<()> {
        if index > self.texts.len() {
            return Err(anyhow!("索引{index}超出范围"));
        }
        result.push(index);

        let feature = self.get_feature(index);
        for i in 0..self.texts.len() {
            if result.contains(&i) {
                continue;
            }
            let feature2 = self.get_feature(i);
            if func(&feature, &feature2) {
                self.operate_text(i, result, func)?;
            }
        }
        result.sort();
        Ok(())
    }

    /// 获取最接近的文本
    pub fn get_nearest_text(&self, index: usize) -> Result<String> {
        let mut tmp =vec![];
        self.operate_text(index, &mut tmp, |a, b| a.font_similar(b) && a.height_nearest(b))?;
        let mut r = String::default();
        for i in tmp {
            r.push_str(&self.texts.get(i).unwrap());
        }
        Ok(r)
    }

    // 获取字体特征
    fn get_feature(&self, index: usize) -> FontFeature {
        let text = self.texts.get(index).unwrap();
        let boxes = self.boxes.get(index).unwrap();
        FontFeature {
            width: boxes.width / text.len() as f64 ,
            height: boxes.height,
            y: boxes.y,
        }
    }

    // 获取同一行的其它数据（获取公司名称）
    pub fn get_same_line(&self, index: usize) -> Result<Vec<usize>> {
        let mut tmp =vec![];
        self.operate_text(index, &mut tmp, |a, b| a.same_line(b))?;
        tmp.retain(|x| *x != index);
        Ok(tmp)
    }
}

impl OcrResult {
    /// 获取编号
    pub fn get_no(&self, res: &Vec<Regex>) -> Result<String> {
        if self.result.texts.is_empty() {
            return Err(anyhow!("未成功识别文字"));
        }

        let mut nos = Vec::new();
        for re in res {
            for text in self.result.texts.iter() {
                if re.is_match(text) {
                    nos.push(text);
                }
            }
        }

        if nos.is_empty() {
            return Err(anyhow!("未成功识别编号"));
        }
        if nos.len() > 1 {
            return Err(anyhow!("识别到多个编号"));
        }

        Ok(nos.get(0).unwrap().to_string())
    }

    /// 获取公司名称
    pub fn get_company_name(&self) -> Result<String> {
        let flag_index = self.result.texts.iter().position(|x| x.ends_with("名称："))
            .ok_or_else(|| anyhow!("未找到[企业名称]"))?;
        if flag_index == self.result.texts.len() - 1 {
            return Err(anyhow!("未找到[企业名称]"));
        }
        let same_lines =  self.result.get_same_line(flag_index)?;
        if same_lines.len() != 1 {
            let mut r = String::new();
            for line in same_lines.iter() {
                r.push_str(&self.result.texts[*line]);
            }
            return Err(anyhow!("查找到多个企业名称，目前只允许一个：[{r}]"));
        }

        Ok(self.result.texts[same_lines[0]].to_string())
    }

    /// 获取标题
    fn get_title(&self) -> Result<String> {
        let flag_index = self.result.texts.iter().position(|x| x.ends_with("检测报告"))
            .ok_or_else(|| anyhow!("未找到[标题]"))?;
        if flag_index == self.result.texts.len() - 1 {
            return Err(anyhow!("未找到[标题]"));
        }
        self.result.get_nearest_text(flag_index)
    }
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

fn export_pdf_to_jpegs(path: &Path, password: Option<&str>) -> Result<(NamedTempFile, i32)> {
    let pdf = PdfiumDocument::new_from_path(path, password)?;
    let page = pdf.page(0)?;
    let config = PdfiumRenderConfig::new().with_width(1920);
    let bitmap = page.render(&config)?;
    let tmp_file = NamedTempFile::with_suffix("jpeg")?;
    bitmap.save(tmp_file.path().to_str().unwrap(), image::ImageFormat::Jpeg)?;
    Ok((tmp_file, pdf.page_count()))
}

mod test {
    use regex::Regex;
    use crate::service::pdf::tar_pdf::{OcrResult, OcrTexts};

    #[test]
    fn test() {
        let texts: OcrResult = serde_json::from_str(r#"这里是mock的数据"#).unwrap();
        let res = vec![ Regex::new(r"[\(|（]\d{4}[\)|）].*[\(|（].*[\)|）].*[\(|（].*[)|）].*").unwrap() ];

        let no = texts.get_no(&res).unwrap();
        println!("no : {no}");
        let company = texts.get_company_name().unwrap();
        println!("company : {company}");
        let title = texts.get_title().unwrap();
        println!("title : {title}");
    }
}