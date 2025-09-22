use crate::common::global_data::GlobalData;
use crate::messages::common::{DataMsg, StringMsg, VecStringMsg};
use crate::messages::tar_pdf::{OcrConfigMsg, OcrDataMsg, RefOcrDatasMsg, RenameFileMsg, TarPdfMsg, TarPdfResultMsg, TarPdfResultsMsg};
use crate::service::service::{Service, StreamService};
use crate::{async_func_nono, async_func_notype, async_func_typetype, async_stream_func_typeno, func_end, func_nono, func_notype, func_typeno, func_typetype};
use anyhow::{anyhow, Result};
use futures_util::StreamExt;
use pdfium::{set_library_location, PdfiumDocument, PdfiumRenderConfig};
use rust_xlsxwriter::{Format, Workbook};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::io::Cursor;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use ahash::{AHashMap, AHashSet};
use calamine::{Data, Reader, Xlsx};
use image::DynamicImage;
use log::{debug, warn};
use strfmt::strfmt;
use tokio::sync::mpsc::UnboundedSender;
use tokio_stream::wrappers::ReadDirStream;
use crate::common::utils::{index_to_string, path_to_file_name, path_to_string};
use crate::service::pdf::ocr::{OcrData, OcrResult};

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
struct OcrConfig {
    // pdf 密码
    pdf_password: Option<String>,
    // ocr识别url
    url: String,
    // ocr识别密钥
    api_key: String,
}

impl OcrConfig {
    /// 是否为有效数据
    fn has_data(&self) -> bool {
        !self.url.is_empty()
            && !self.api_key.is_empty()
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
        }
    }
}

impl Into<OcrConfigMsg> for OcrConfig {
    fn into(self) -> OcrConfigMsg {
        OcrConfigMsg {
            passwd: self.pdf_password,
            url: self.url,
            api_key: self.api_key,
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

/// OCR识别结果
#[derive(Debug)]
struct OcrPdfData {
    // 文件路径
    pdf: PathBuf,
    // 识别数据 k: tag v: text
    datas: Result<AHashMap<String, Result<String>>>,
    // 格式化结果
    template_result: Result<String>,
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
    // 识别结果
    ocr_data: Vec<OcrPdfData>
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
        async_stream_func_typeno!(self, func, req_data, handle, VecStringMsg, tx);
        func_end!(func)
    }
}

#[async_trait::async_trait]
impl Service for TarPdfService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_typeno!(self, func, req_data, set_config, OcrConfigMsg, set_ref_config_tags, VecStringMsg);
        func_notype!(self, func, get_config, get_ocr_pdf_data);
        func_typetype!(self, func, req_data, set_ref_config_template, StringMsg);
        func_nono!(self, func, reset);
        async_func_nono!(self, func, ocr_check);
        async_func_notype!(self, func, export_excel);
        async_func_typetype!(self, func, req_data, scan_pdf, StringMsg, get_pdf_cover, StringMsg, set_ref_config, StringMsg, rename_by_excel, StringMsg);

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
        pdf_files: VecStringMsg,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()> {
        // 1. 配置检查
        self.ocr_check().await?;
        if self.ref_data.is_none() || self.ref_config.tags.is_empty() || self.ref_config.template.is_empty() {
            return Err(anyhow!("请先设置参考数据"));
        }

        // 2. 转换files文件为path,并排序
        let pdf_files = {
          let mut files =  Vec::with_capacity(pdf_files.values.len());
            for file in pdf_files.values {
                let path = PathBuf::from(file);
                if path.is_dir() || !path.exists() {
                    return Err(anyhow!("文件「{}」不存在", path.as_os_str().to_str().unwrap()));
                }
                if path.is_file() {
                    files.push(path.to_path_buf());
                }
            }

            // 对文件进行排序
            sort_pdf_files(&mut files).await?;
            files
        };

        // 3. handle
        self.ocr_data.clear();
        let url = self.config.ocr_url();
        let count = pdf_files.len();
        for (index, pdf_file) in pdf_files.into_iter().enumerate() {
            // 发送当前处理进度
            let file_name = pdf_file
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

            // 文本处理
            let ocr_data = self.handle_pdf(pdf_file, &url, index).await;

            // 保存结果
            self.ocr_data.push(ocr_data);
        }

        Ok(())
    }

    fn get_ocr_pdf_data(&self) -> Result<TarPdfResultsMsg> {
        // 1. 查找所有tags
        let tags: Vec<String> = self.ref_config.tags.iter().map(|x| x.clone()).collect();

        let mut result = Vec::with_capacity(self.ocr_data.len());
        for data in self.ocr_data.iter() {
           result.push(Self::ocr_data2msg(&tags, data)?);
        }

        Ok(TarPdfResultsMsg{
            tags,
            datas: result,
        })
    }

    /// 导出结果并重命名文件
    /// return 导出后的文件
    async fn export_excel(&self) -> Result<StringMsg> {
        if self.ocr_data.is_empty() {
            return Err(anyhow!("无识别结果"));
        }

        let file = self.write_excel_file().await?;
        Ok(StringMsg { value: path_to_string(&file)? })
    }

    /// 根据excel重命名文件
    async fn rename_by_excel(&self, xlsx_file: StringMsg) -> Result<RenameFileMsg> {
        // 1.解析excel
        let mut workbook: Xlsx<_> = calamine::open_workbook(&xlsx_file.value)?;
        let range = workbook.worksheet_range_at(0).ok_or_else(|| anyhow!("无法打开Sheet"))??;

        let mut files = Vec::new();
        for (row_index, row) in range.rows().enumerate() {
            // 1. 检查首行数据是否正确
            if row_index == 0 {
                if row.len() < 2 {
                    return Err(anyhow!("格式不正确,请不要修改首行数据"));
                }
                if let Ok(d) = Self::read_cell_as_string(row, 0) && d == "原始文件" {
                } else {
                    return Err(anyhow!("格式不正确,请不要修改首行数据"));
                }
                if let Ok(d) = Self::read_cell_as_string(row, 1) && d == "命名结果" {
                } else {
                    return Err(anyhow!("格式不正确,请不要修改首行数据"));
                }
                continue;
            }

            // 2. 读取数据
            if row.len() < 2 {
                continue;
            }
            if let Ok(d1) = Self::read_cell_as_string(row, 0) && let Ok(d2) = Self::read_cell_as_string(row, 1) {
                let mut path = PathBuf::from(d1);
                path.pop();
                path.push(d2);
                files.push((d1, path_to_string(&path)?));
            } else {
                warn!("行[{}]数据错误", row_index+1);
            }
        }

        // 2. 重命名
        let mut result = Vec::new();
        for (target, dest) in files {
            if let Err(e) = tokio::fs::rename(target, dest).await {
                result.push((target.clone(), e.to_string()));
            }
        }

        Ok(RenameFileMsg {
            value: result
        })
    }

    // 读取单元格数据
    fn read_cell_as_string(row: &[Data], index: usize) -> Result<&String> {
        let data = row.get(index).ok_or_else(|| anyhow!("不能读取列： {}", index))?;
        if let Data::String(data) = data {
            return Ok(data);
        }
        Err(anyhow!("无法单元格为string"))
    }

    /// 重置数据
    fn reset(&mut self) -> Result<()> {
        self.ocr_data.clear();
        self.ref_data = None;
        self.ref_config = Default::default();
        Ok(())
    }

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
            values: pdf_files.into_iter().map(|x| x.into_os_string().into_string().unwrap()).collect()
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
        let (img, _pages, ocr_result) = self.ocr_pdf(&pdf, &self.config.ocr_url()).await?;
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
        self.ref_config.tags.insert("pages".to_string());
        self.ref_config.tags.insert("order".to_string());
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
        let ref_data= self.ref_data.as_ref().unwrap();
        for tag in self.ref_config.tags.iter() {
            if tag == "pages" || tag == "order"{
                continue;
            }
            data_map.insert(tag.clone(), ref_data.image_ocr.get(tag).ok_or_else(|| anyhow!("没有找到tag: {}", tag))?.text.clone());
        }

        data_map.insert("pages".to_string(), 10.to_string());
        data_map.insert("order".to_string(), 1.to_string());
        let result = strfmt(&template.value, &data_map)?;

        self.ref_config.template = template.value;
        Ok(StringMsg{
            value: result,
        })
    }
}

impl TarPdfService {
    pub async fn new(global_data: GlobalData) -> Self {
        let config: OcrConfig = global_data
            .get_data(CONFIG_CACHE.to_string())
            .await
            .unwrap_or_default();

        TarPdfService {
            global_data,
            config,
            ref_data: None,
            ref_config: Default::default(),
            ocr_data: Default::default(),
        }
    }


    const MIN_SCORE: f64 = 0.9;
    /// 处理一个pdf
    async fn handle_pdf(&self, pdf: PathBuf, url: &str, index: usize) -> OcrPdfData {
        // 1. ocr pdf
        let (_, pages, ocr_result) = match self.ocr_pdf(&pdf, url).await {
            Ok(r) => r,
            Err(e) => {
                return OcrPdfData {
                    pdf,
                    datas: Err(e),
                    template_result: Ok(String::with_capacity(0)),
                };
            }
        };

        // 2. 对比数据
        let target_ocr_data = ocr_result.result.into_ocr_data();
        let mut tmp_result = Vec::with_capacity(target_ocr_data.len());
        for tag in &self.ref_config.tags {
            let ref_data = match self.ref_data.as_ref().unwrap().image_ocr.get(tag) {
                None => {Err(anyhow!("未找到参考标签：{}", tag))},
                Some(ref_data) => {
                  match ref_data.find_similar_text(&target_ocr_data, Self::MIN_SCORE) {
                      Ok(data) => {
                          match data {
                              None => {Err(anyhow!("未找到相似文本:{}", tag))}
                              Some(d) => {Ok(d)}
                          }
                      }
                      Err(e) => {Err(e)},
                  }
                },
            };
            tmp_result.push((tag, ref_data));
        }

        // 3. 构造数据
        let mut result_datas = AHashMap::with_capacity(tmp_result.len());
        for (tag, ref_data) in tmp_result {
            let ref_data = ref_data.map(|x| {
                x.text.clone()
            }).map_err(|e| anyhow!(e));
            result_datas.insert(tag.clone(), ref_data);
        }
        result_datas.insert("pages".to_string(), Ok(pages.to_string()));
        result_datas.insert("order".to_string(), Ok((index+1).to_string()));

        // 4. 模板处理
        let mut template_map = HashMap::new();
        for (tag, data) in result_datas.iter() {
            if let Ok(data) = data {
                template_map.insert(tag.clone(), data.clone());
            }
        }
        let template_result = strfmt(&self.ref_config.template, &mut template_map).map_err(|e| anyhow!(e));

        OcrPdfData {
            pdf,
            datas: Ok(result_datas),
            template_result,
        }
    }

    /// ocr_pdf
    async fn ocr_pdf(&self, pdf_file: &PathBuf, url: &str) -> Result<(DynamicImage, usize, OcrResult)> {
        // 1. 文本识别
        let pdf_password = self.config.pdf_password.clone();
        let pdf_file = pdf_file.clone();
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
        debug!("识别数据: {:?}", ocr_result);

        Ok((img, pages as usize, ocr_result))
    }

    /// 导出结果
    async fn write_excel_file(&self) -> Result<PathBuf> {
        // 1. 创建文件
        let mut file = self.ocr_data.get(0).unwrap().pdf.clone();
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

        // 创建表头
        worksheet.write_with_format(0, 0, "原始文件", &header_format)?;
        worksheet.write_with_format(0, 1, "命名结果", &header_format)?;
        worksheet.write_with_format(0, 2, "错误信息", &header_format)?;
        let mut tags = Vec::with_capacity(self.ref_config.tags.len());
        for (i, tag) in self.ref_config.tags.iter().enumerate() {
            worksheet.write_with_format(0, i as u16 + 3, tag, &header_format)?;
            tags.push(tag);
        }

        // 创建数据行
        for (index, pdf) in self.ocr_data.iter().enumerate() {
            let row = (index + 1) as u32;
            worksheet.write(row, 0, path_to_string(&pdf.pdf)?)?;
            match &pdf.template_result {
                Ok(d) => {worksheet.write(row, 1, d)?;},
                Err(e) => {worksheet.write_with_format(row, 2, e.to_string(), &error_format)?;}
            };

            match &pdf.datas {
                Err(e) => {worksheet.write_with_format(row, 2, e.to_string(), &error_format)?;},
                Ok(data) => {
                    let mut column: u16 = 2;
                    for tag in tags.iter() {
                        column += 1;
                        match data.get(*tag) {
                            Some(item) => {
                                match item {
                                    Ok(item) => {
                                        worksheet.write(row, column, item)?;
                                    },
                                    Err(e) => {
                                        worksheet.write_with_format(row, column , e.to_string(), &error_format)?;
                                    }
                                };
                            },
                            None => {
                                worksheet.write_with_format(row, column, "无法找到对应标签的值", &error_format)?;
                            }
                        };
                    }
                }
            }
        }

        // 3. 保存文件
        workbook.save(&file)?;

        Ok(file)
    }

    /// 转换数据为MSG
    fn ocr_data2msg(tags: &Vec<String>, data: &OcrPdfData) -> Result<TarPdfResultMsg> {
        // 1. 获取文件名
        let file_name = path_to_file_name(&data.pdf)?;
        if let Err(e) = &data.datas {
            return Ok(TarPdfResultMsg {
                file_name,
                datas: Default::default(),
                template_result: Default::default(),
                error: e.to_string(),
            })
        }

        // 2. 填充数据
        let mut result_datas = HashMap::with_capacity(tags.len());
        let datas = data.datas.as_ref().unwrap();
        for tag in tags {
            let r = match datas.get(tag) {
                None => {
                    (String::with_capacity(0), format!("未能查找到标识{}", tag))
                }
                Some(d) => {
                    match d {
                        Ok(r) => { (r.clone(), String::with_capacity(0))}
                        Err(e) => {(String::with_capacity(0), e.to_string())}
                    }
                }
            };
            result_datas.insert(tag.clone(), r);
        }

        // 3. 填充模板
        match &data.template_result {
            Ok(d) => {
                Ok(TarPdfResultMsg {
                    file_name,
                    datas: result_datas,
                    template_result: d.clone(),
                    error: String::with_capacity(0),
                })
            }
            Err(e) => {
                Ok(TarPdfResultMsg {
                    file_name,
                    datas: result_datas,
                    template_result: String::with_capacity(0),
                    error: e.to_string(),
                })
            }
        }
    }
}

// 非递归获取指定目录中的所有PDF文件
async fn get_pdf_files_in_directory(dir: &Path) -> Result<Vec<PathBuf>> {
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

        // 只处理文件，不递归处理子目录
        if path.is_file() {
            // 检查文件扩展名是否为PDF
            if let Some(ext) = path.extension() && ext.eq_ignore_ascii_case("pdf") {
                pdf_files.push(path);
            }
        }
    }

    Ok(pdf_files)
}

/// 按创建时间对文件进行排序
async fn sort_pdf_files(pdf_files: &mut Vec<PathBuf>) -> Result<()> {
    let mut pdf_files_with_time = Vec::with_capacity(pdf_files.len());

    for pdf in pdf_files.drain(..) {
        let metadata = tokio::fs::metadata(&pdf).await?;
        let created_time = metadata.created().unwrap_or(UNIX_EPOCH);
        pdf_files_with_time.push((pdf, created_time));
    }

    pdf_files_with_time.sort_by(|a, b| b.1.cmp(&a.1));

    *pdf_files = pdf_files_with_time.into_iter().map(|x| x.0).collect();

    Ok(())
}


fn export_pdf_to_jpegs(path: &Path, password: Option<&str>) -> Result<(DynamicImage, i32)> {
    if cfg!(target_os = "linux") {
        set_library_location("/home/nsfoxer/桌面/src/nftools/assets/bin/");
    }
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


