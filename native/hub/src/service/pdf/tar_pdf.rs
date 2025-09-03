use crate::common::global_data::GlobalData;
use crate::messages::common::StringMsg;
use crate::messages::tar_pdf::{OcrConfigMsg, TarPdfMsg, TarPdfResultMsg, TarPdfResultsMsg};
use crate::service::service::{Service, StreamService};
use crate::{async_func_nono, async_func_notype, async_stream_func_typeno, func_end, func_nono, func_notype, func_typeno};
use anyhow::{anyhow, Result};
use futures_util::StreamExt;
use log::debug;
use pdfium::{PdfiumDocument, PdfiumRenderConfig};
use regex::Regex;
use rust_xlsxwriter::{Format, Workbook};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use serde_with::serde_as;
use serde_with::DisplayFromStr;
use std::cmp::Ordering;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use strfmt::strfmt;
use tempfile::NamedTempFile;
use tokio::sync::mpsc::UnboundedSender;
use tokio_stream::wrappers::ReadDirStream;

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
        func_notype!(self, func, get_config, get_result);
        func_nono!(self, func, clear_result);
        async_func_nono!(self, func, ocr_check);
        async_func_notype!(self, func, export_result_and_rename_files);

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

    async fn handle(
        &mut self,
        pdf_dir: StringMsg,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
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
            let file_name = pdf_file
                .path
                .file_name()
                .unwrap_or_default()
                .to_str()
                .unwrap_or_default()
                .to_string();
            let msg = rinf::serialize(&TarPdfMsg {
                now: (index+1) as u32,
                sum: count as u32,
                current_file: file_name,
            });
            tx.send(Ok(Some(msg?)))?;

            // 处理OCR
            let ocr = self
                .ocr_pdf(pdf_file.path.clone(), index as u32, &url)
                .await;

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
        let data = self
            .result
            .iter()
            .map(|x| {
                let file_name = x
                    .file_path
                    .file_name()
                    .unwrap()
                    .to_str()
                    .unwrap()
                    .to_string();
                let mut ocr_result = TarPdfResultMsg::default();
                ocr_result.file_name = file_name;
                match &x.ocr_result {
                    Ok(r) => {
                        ocr_result.company = r.company_name.clone();
                        ocr_result.title = r.title.clone();
                        ocr_result.no = r.no.clone();
                        ocr_result.error_msg = String::with_capacity(0);
                        ocr_result.pages = r.pages;
                    }
                    Err(e) => {
                        ocr_result.error_msg = e.to_string();
                    }
                };
                ocr_result
            })
            .collect();
        Ok(TarPdfResultsMsg { datas: data })
    }

    /// 导出结果并重命名文件
    /// return 导出后的文件
    async fn export_result_and_rename_files(&mut self) -> Result<StringMsg> {
        if self.result.is_empty() {
            return Err(anyhow!("无识别结果"));
        }

        // 1. 重命名文件
        for pdf in self.result.iter_mut() {
            if let Err(e) = Self::rename_pdf(pdf, &self.config.export_file_name_rule).await {
                pdf.ocr_result = Err(e);
            }
        }

        // 2. 导出excel表格
        let file = self.write_excel_file().await?;
        let name = file
            .file_name()
            .unwrap_or_default()
            .to_str()
            .unwrap_or_default()
            .to_string();
        Ok(StringMsg { value: name })
    }

    fn clear_result(&mut self) -> Result<()> {
        self.result.clear();
        Ok(())
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
            result: Vec::new(),
        }
    }

    // ocr_pdf
    async fn ocr_pdf(&self, pdf_file: PathBuf, index: u32, url: &str) -> Result<ExcelData> {
        // 1. 文本识别
        let pdf_path = pdf_file.to_str().unwrap().to_string();
        let pdf_password = self.config.pdf_password.clone();
        let (img, pages) = tokio::task::spawn_blocking(move || {
            export_pdf_to_jpegs(&pdf_file, pdf_password.as_deref())
        })
        .await??;
        let form = reqwest::multipart::Form::new().file("file", img).await?;
        let result = reqwest::Client::new()
            .post(url)
            .header("api-key", &self.config.api_key)
            .multipart(form)
            .send()
            .await?;
        let text = result.text().await?;
        debug!("ocr url response: {}", text);
        let mut ocr_result: OcrResult = serde_json::from_str(&text)?;

        // 2. 识别数据
        ocr_result.result.clear_fuzzy_data();
        // a. 识别编号
        let no = ocr_result.get_no(&self.config.no_regex_match)?;
        // b. 识别公司名称
        let company = ocr_result.get_company_name()?;
        // c. 识别标题
        let title = ocr_result.get_title()?;

        Ok(ExcelData {
            file_name: pdf_path,
            index: index + 1,
            no,
            pages,
            company_name: company,
            title,
        })
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

    async fn write_excel_file(&self) -> Result<PathBuf> {
        if self.result.is_empty() {
            return Err(anyhow!("无识别结果"));
        }
        // 1. 创建文件
        let mut file = self.result.get(0).unwrap().file_path.clone();
        file.pop();
        let now = SystemTime::now();
        file.push(format!(
            "检测报告识别结果_{}.xlsx",
            now.duration_since(UNIX_EPOCH)?.as_millis()
        ));

        // 2. 写入数据
        let mut workbook = Workbook::new();
        let worksheet = workbook.add_worksheet().set_name("sheet1")?;
        // 定义一些单元格样式
        let header_format = Format::new()
            .set_bold()
            .set_background_color(rust_xlsxwriter::Color::RGB(0xD9E1F2))
            .set_border(rust_xlsxwriter::FormatBorder::Thin);
        let error_format =
            Format::new().set_background_color(rust_xlsxwriter::Color::RGB(0xFFC7CE));
        let number_format = Format::new().set_num_format("0");

        // 创建表头
        worksheet.write_with_format(0, 0, "原始文件", &header_format)?;
        worksheet.write_with_format(0, 1, "序号", &header_format)?;
        worksheet.write_with_format(0, 2, "文件名称", &header_format)?;
        worksheet.write_with_format(0, 3, "文件编号", &header_format)?;
        worksheet.write_with_format(0, 4, "页数", &header_format)?;
        worksheet.write_with_format(0, 5, "错误信息", &header_format)?;

        // 创建数据行
        for (index, pdf) in self.result.iter().enumerate() {
            let row = (index + 1) as u32;
            worksheet.write(
                row,
                0,
                pdf.file_path
                    .file_name()
                    .unwrap_or_default()
                    .to_str()
                    .unwrap_or_default(),
            )?;
            worksheet.write_number_with_format(row, 1, (index + 1) as f64, &number_format)?;
            match &pdf.ocr_result {
                Ok(data) => {
                    worksheet.write(row, 2, format!("{}{}", data.company_name, data.title))?;
                    worksheet.write(row, 3, &data.no)?;
                    worksheet.write_number_with_format(
                        row,
                        4,
                        data.pages as f64,
                        &number_format,
                    )?;
                }
                Err(e) => {
                    worksheet.write_with_format(row, 5, e.to_string(), &error_format)?;
                }
            };
        }

        // 3. 保存文件
        workbook.save(&file)?;

        Ok(file)
    }
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

#[derive(Debug, Deserialize)]
struct OcrResult {
    result: OcrTexts,
}
#[serde_as]
#[derive(Debug, Deserialize)]
struct OcrTexts {
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
        (self.width - other.width).abs() / self.width < 0.14
            && (self.height - other.height).abs() / self.height < 0.14
    }

    // 高度接近(上下行排列)
    fn height_nearest(&self, other: &Self) -> bool {
        (self.y - other.y).abs() / self.height < 2.8 && (self.y - other.y).abs() / self.height > 1.0
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
    fn operate_text(
        &self,
        index: usize,
        result: &mut Vec<usize>,
        func: fn(&FontFeature, &FontFeature) -> bool,
    ) -> Result<()> {
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
        let mut tmp = vec![];
        self.operate_text(index, &mut tmp, |a, b| {
            a.font_similar(b) && a.height_nearest(b)
        })?;
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
            width: boxes.width / text.len() as f64,
            height: boxes.height,
            y: boxes.y,
        }
    }

    // 获取同一行的其它数据（获取公司名称）
    pub fn get_same_line(&self, index: usize) -> Result<Vec<usize>> {
        let mut tmp = vec![];
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
        let flag_index = self
            .result
            .texts
            .iter()
            .position(|x| x.ends_with("名称："))
            .ok_or_else(|| anyhow!("未找到[企业名称]"))?;
        if flag_index == self.result.texts.len() - 1 {
            return Err(anyhow!("未找到[企业名称]"));
        }
        let same_lines = self.result.get_same_line(flag_index)?;
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
        let flag_index = self
            .result
            .texts
            .iter()
            .position(|x| x.ends_with("检测报告"))
            .ok_or_else(|| anyhow!("未找到[标题]"))?;
        if flag_index == self.result.texts.len() - 1 {
            return Err(anyhow!("未找到[标题]"));
        }
        self.result.get_nearest_text(flag_index)
    }
}

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
    use crate::service::pdf::tar_pdf::ExcelData;

    #[test]
    fn test() {
        use crate::service::pdf::tar_pdf::OcrResult;
        use regex::Regex;

        let texts: OcrResult = serde_json::from_str(r#"这里是mock的数据"#).unwrap();
        let res =
            vec![Regex::new(r"[\(|（]\d{4}[\)|）].*[\(|（].*[\)|）].*[\(|（].*[)|）].*").unwrap()];

        let no = texts.get_no(&res).unwrap();
        println!("no : {no}");
        let company = texts.get_company_name().unwrap();
        println!("company : {company}");
        let title = texts.get_title().unwrap();
        println!("title : {title}");
    }

    #[test]
    fn test2() {
        let excel = ExcelData::default();
        let rule = r#"{index}{no}{company_name}{title}-xxx.xlsx"#;
        let r = excel.convert_file_name(rule).unwrap();
        assert_eq!("0-xxx.xlsx", r);
    }
}
