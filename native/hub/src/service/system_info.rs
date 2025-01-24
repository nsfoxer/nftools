use anyhow::{anyhow, Result};
use fast_inv_sqrt::InvSqrt64;
use log::error;
use prost::Message;
use std::ops::Sub;
use std::time::{Duration, SystemTime};
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

use crate::common::utils::{get_cache_dir, second_timestamp};
use crate::messages::system_info::{ChartInfo, ChartInfoReq, ChartInfoRsp, SystemInfoCache};
use crate::service::service::{Service, ServiceName};
use crate::{async_func_nono, func_end, func_notype, func_typetype};

// 缓存文件
const CACHE_FILE: &str = "system_info.cache";
// 图形筛选阈值(rdp算法阈值)
#[allow(unused)]
const THRESHOLD: f64 = 5.0;
// 需要清理的数据最大上限
const CLEAR_MAX_SIZE: usize = 3600 * 24 * 3;
// 数据最大上限
const MAX_SIZE: usize = 3600 * 24 * 2;

/// 系统信息服务
pub struct SystemInfoService {
    /// 系统信息读取
    sys: System,
    /// cpu所有数据
    cpu_datas: Vec<ChartInfo>,
    /// mem所有数据
    mem_datas: Vec<ChartInfo>,
}

impl ServiceName for SystemInfoService {
    fn get_service_name(&self) -> &'static str {
        "SystemInfo"
    }
}

#[async_trait::async_trait]
impl Service for SystemInfoService {
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_notype!(self, func, get_cpu, get_ram);
        func_typetype!(
            self,
            func,
            req_data,
            get_cpu_datas,
            ChartInfoReq,
            get_mem_datas,
            ChartInfoReq
        );
        async_func_nono!(self, func, close);
        func_end!(func)
    }

    async fn close(&mut self) -> Result<()> {
        let mut path = match get_cache_dir() {
            Ok(r) => r,
            Err(e) => {
                error!("保存system_info数据失败{e}");
                return Ok(());
            }
        };
        path.push(CACHE_FILE);

        // 优化数据
        optimize_data(&mut self.cpu_datas, true);
        optimize_data(&mut self.mem_datas, true);
        let cache = SystemInfoCache {
            mem_datas: Some(ChartInfoRsp {
                infos: self.mem_datas.clone(),
            }),
            cpu_datas: Some(ChartInfoRsp {
                infos: self.cpu_datas.clone(),
            }),
        };

        let buf = cache.encode_to_vec();
        if let Ok(buf) = lzma::compress(&buf, 9) {
            if let Ok(mut file) = File::create(path).await {
                file.write_all(&buf[..]).await?;
            }
        }

        Ok(())
    }
}

impl SystemInfoService {
    /// 获取cpu实时数据
    fn get_cpu(&mut self) -> Result<ChartInfo> {
        let value = (self.sys.global_cpu_usage() * 100.0) as u32;
        self.sys.refresh_cpu_usage();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value,
        };
        self.cpu_datas.push(info.clone());
        optimize_data(&mut self.cpu_datas, false);
        Ok(info)
    }

    /// 获取ram实时数据
    fn get_ram(&mut self) -> Result<ChartInfo> {
        self.sys.refresh_memory();
        let value = self.sys.used_memory() * 10000 / self.sys.total_memory();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value: value as u32,
        };
        self.mem_datas.push(info.clone());
        optimize_data(&mut self.mem_datas, false);
        Ok(info)
    }

    fn get_cpu_datas(&mut self, req: ChartInfoReq) -> Result<ChartInfoRsp> {
        Self::get_data(req, &self.cpu_datas)
    }

    fn get_mem_datas(&mut self, req: ChartInfoReq) -> Result<ChartInfoRsp> {
        Self::get_data(req, &self.mem_datas)
    }
}

impl SystemInfoService {
    /// 新建
    pub async fn new() -> Self {
        let res = RefreshKind::new()
            .with_cpu(CpuRefreshKind::everything())
            .with_memory(MemoryRefreshKind::new().with_ram());
        let mut sys = System::new_with_specifics(res);
        sys.refresh_all();
        let (cpu_datas, mem_datas) = Self::load_datas().await;
        Self {
            sys,
            cpu_datas,
            mem_datas,
        }
    }

    /// 加载本地数据
    async fn load_datas() -> (Vec<ChartInfo>, Vec<ChartInfo>) {
        let mut cpu_datas = Vec::new();
        let mut mem_datas = Vec::new();
        let mut path = match get_cache_dir() {
            Ok(r) => r,
            Err(_) => {
                return (cpu_datas, mem_datas);
            }
        };
        path.push(CACHE_FILE);
        if let Ok(mut file) = File::open(path).await {
            let mut buf = Vec::new();
            let _ = file.read_to_end(&mut buf).await;
            if let Ok(buf) = lzma::decompress(&buf) {
                if let Ok(r) = SystemInfoCache::decode(&buf[..]) {
                    cpu_datas = r.cpu_datas.unwrap_or_default().infos;
                    mem_datas = r.mem_datas.unwrap_or_default().infos;
                }
            }
        }

        (cpu_datas, mem_datas)
    }
    /// 获取一定范围内的数据
    fn get_data(req: ChartInfoReq, datas: &Vec<ChartInfo>) -> Result<ChartInfoRsp> {
        let start = match find_index(req.start_time, datas) {
            None => {
                return Ok(ChartInfoRsp::default());
            }
            Some(r) => r,
        };
        let end = match find_index(req.end_time, datas) {
            None => {
                return Ok(ChartInfoRsp::default());
            }
            Some(r) => r,
        };

        if start >= end {
            return Ok(ChartInfoRsp::default());
        }

        Ok(ChartInfoRsp {
            infos: datas
                .iter()
                .skip(start)
                .take(end - start)
                .cloned()
                .collect(),
        })
    }
}

/// 删除过期数据
fn optimize_data(datas: &mut Vec<ChartInfo>, force: bool) {
    if force {
        // 强制删除
        let timestamp = SystemTime::now()
            .sub(Duration::from_secs(3600 * 48))
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as u32;
        if let Some(id) = find_index(timestamp, datas) {
            datas.drain(0..id);
        }
        return;
    }

    // 非强制删除
    if datas.len() > CLEAR_MAX_SIZE {
        datas.drain(0..CLEAR_MAX_SIZE - MAX_SIZE);
    }
}

// 查找索引
fn find_index(data: u32, datas: &Vec<ChartInfo>) -> Option<usize> {
    if datas.len() < 2 {
        return None;
    }

    let mut start = 0;
    let mut end = datas.len() - 1;
    let mut mid = (end - start) / 2 + start;
    while start <= end {
        mid = (end - start) / 2 + start;
        if data < datas[mid].timestamp {
            if mid == 0 {
                break;
            }
            end = mid - 1;
            if mid - 1 > 0 && data > datas[mid - 1].timestamp {
                break;
            }
        } else if data > datas[mid].timestamp {
            start = mid + 1;
            if start > datas.len() {
                break;
            }
            if mid + 1 < datas.len() && data < datas[mid + 1].timestamp {
                break;
            }
        } else {
            break;
        }
    }

    Some(mid)
}

/// rdp算法 不再使用
/// 去除不必要的数据点，将需要去除的点的mark标记为true
/// datas长度与delete_marks长度必须一致
#[allow(unused)]
fn optimize_datas(datas: &[ChartInfo], delete_marks: &mut [bool], threshold: f64) -> Result<()> {
    if datas.len() != delete_marks.len() {
        return Err(anyhow!("参数长度不一致"));
    }
    // 小于2个点，则不必要继续
    if datas.len() < 3 {
        return Ok(());
    }

    // 计算每个点到线段的距离
    let p1 = Point {
        x: datas.first().unwrap().timestamp,
        y: datas.first().unwrap().value as f64,
    };
    let p2 = Point {
        x: datas.last().unwrap().timestamp,
        y: datas.last().unwrap().value as f64,
    };
    let equation = LineEquation::new(p1, p2).ok_or(anyhow!("无法计算直线函数"))?;
    let mut max_distance = 0.0;
    let mut max_index = 0;
    for (i, data) in datas.iter().enumerate() {
        // 去除第一个和最后一个点，去除已删除的点
        if i == 0 || i == datas.len() || delete_marks[i] {
            continue;
        }
        let distance = equation.cal_distance(Point {
            x: data.timestamp,
            y: data.value as f64,
        });
        if distance > max_distance {
            max_index = i;
            max_distance = distance;
        }
    }

    // 如果最大距离小于阈值，则删除所有点（除第一和最后一个点）
    if max_distance < threshold {
        delete_marks.fill(true);
        delete_marks[0] = false;
        delete_marks[delete_marks.len() - 1] = false;
        return Ok(());
    }

    // 否则，递归进行运算
    optimize_datas(
        &datas[..=max_index],
        &mut delete_marks[..=max_index],
        threshold,
    )?;
    optimize_datas(
        &datas[max_index..],
        &mut delete_marks[max_index..],
        threshold,
    )?;

    Ok(())
}

#[derive(Debug)]
struct Point {
    x: u32,
    y: f64,
}

#[derive(Debug)]
struct LineEquation {
    k: f64,
    b: f64,
}

#[allow(unused)]
impl LineEquation {
    fn new(p1: Point, p2: Point) -> Option<Self> {
        if p2.x == p1.x {
            return None;
        }
        let k = (p2.y - p1.y) / (p2.x - p1.x) as f64;
        let b = p1.y - k * p1.x as f64;

        Some(Self { k, b })
    }

    fn cal_distance(&self, p: Point) -> f64 {
        let divisor = (self.k * p.x as f64 - p.y + self.b).abs();
        let dividend = (1.0 + self.k * self.k).inv_sqrt64();

        divisor * dividend
    }
}

#[allow(unused_imports)]
mod test {
    use crate::messages::system_info::ChartInfo;
    use crate::service::system_info::{
        find_index, optimize_datas, LineEquation, Point, SystemInfoService, THRESHOLD,
    };
    use fast_inv_sqrt::InvSqrt32;
    use rand::{thread_rng, Rng};

    #[test]
    fn test_index() {
        let mut datas = Vec::new();
        for i in 0..100 {
            datas.push(ChartInfo {
                timestamp: i * 2,
                value: i,
            })
        }

        let r = find_index(0, &datas).unwrap();
        assert_eq!(r, 0);
        let r = find_index(400, &datas).unwrap();
        assert_eq!(r, 99);
    }
    #[test]
    fn test_equation() {
        let p1 = Point { x: 10, y: 5.0 };
        let p2 = Point { x: 100, y: 3.0 };

        let r = LineEquation::new(p1, p2).unwrap();
        eprintln!("{r:?}");
        let r2 = r.cal_distance(Point { x: 100, y: 10.0 });
        assert!((r.k - -0.022).abs() < 0.001);
        eprintln!("{r2}");
        assert!((r2 - 6.998).abs() < 0.1);
    }

    #[test]
    fn sqrt() {
        let x = 1600.01f32;
        eprintln!("{}, {}", x.inv_sqrt32(), 1.0 / x.sqrt());
        assert!((x.inv_sqrt32() - 1.0 / x.sqrt()).abs() < 0.01);
    }

    #[test]
    fn dotdot() {
        let t = [0, 1, 2, 3, 4];
        assert_eq!(t[3..], [3, 4])
    }

    #[test]
    fn optiminze() {
        let mut rng = thread_rng();
        let mut original_datas = Vec::new();
        for i in 0..100 {
            original_datas.push(ChartInfo {
                timestamp: i,
                value: rng.gen_range(1000..10000),
            });
        }
        let mut delete_marks = vec![false; original_datas.len()];
        optimize_datas(&original_datas[..], &mut delete_marks[..], THRESHOLD).unwrap();
        let mut optimize_datas = Vec::new();
        for (i, data) in original_datas.iter().enumerate() {
            if !delete_marks[i] {
                optimize_datas.push(data.clone());
            }
        }

        eprintln!("=============");
        for d in original_datas {
            eprintln!("{}", d.value);
        }
        eprintln!("=============");
        for d in optimize_datas {
            eprintln!("{}", d.value);
        }
    }

    // 输出缓存数据大概情况
    #[tokio::test]
    async fn print_datas() {
        let system_info = SystemInfoService::new().await;
        eprintln!("cpu history datas ========= ");
        eprintln!(
            "len = {}, start = {:?}, end = {:?}",
            system_info.cpu_datas.len(),
            system_info.cpu_datas.first().unwrap(),
            system_info.cpu_datas.last().unwrap()
        );
        eprintln!("mem history datas ========= ");
        eprintln!(
            "len = {}, start = {:?}, end = {:?}",
            system_info.mem_datas.len(),
            system_info.mem_datas.first().unwrap(),
            system_info.mem_datas.last().unwrap()
        );
    }
}
