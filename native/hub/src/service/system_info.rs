use std::io::Write;
use std::os::raw::c_double;
use anyhow::{anyhow, Result};
use dirs::data_local_dir;
use fast_inv_sqrt::InvSqrt64;
use log::error;
use prost::Message;
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};
use tokio::fs::File;
use tokio::io::AsyncReadExt;

use crate::common::utils::{get_data_dir, second_timestamp};
use crate::messages::system_info::{ChartInfo, ChartInfoReq, ChartInfoRsp, SystemInfoCache};
use crate::service::service::Service;
use crate::{func_end, func_notype, func_typetype};

// 缓存文件
const CACHE_FILE: &str = "system_info.cache";

/// 系统信息服务
pub struct SystemInfoService {
    /// 系统信息读取
    sys: System,
    /// cpu所有数据
    cpu_datas: Vec<ChartInfo>,
    /// 已优化的cpu数据
    history_cpu_datas: Vec<ChartInfo>,
    /// mem所有数据
    mem_datas: Vec<ChartInfo>,
    /// 已优化的mem数据
    history_mem_datas: Vec<ChartInfo>,
}


#[async_trait::async_trait]
impl Service for SystemInfoService {
    fn get_service_name(&self) -> &'static str {
        "SystemInfo"
    }

    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
        func_notype!(self, func, get_cpu, get_ram);
        func_typetype!(self, func, req_data, get_cpu_datas, ChartInfoReq, get_mem_datas, ChartInfoReq);
        func_end!(func)
    }
}

impl SystemInfoService {
    /// 获取cpu实时数据
    fn get_cpu(&mut self) -> Result<ChartInfo> {
        let value = (self.sys.global_cpu_usage() * 10000.0) as u32;
        self.sys.refresh_cpu_usage();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value,
        };
        self.add_cpu_info(info.clone());
        Ok(info)
    }

    /// 获取ram实时数据
    fn get_ram(&mut self) -> Result<ChartInfo> {
        self.sys.refresh_memory();
        let value = self.sys.used_memory() * 1000 / self.sys.total_memory();
        let info = ChartInfo {
            timestamp: second_timestamp(),
            value: value as u32,
        };
        self.add_mem_info(info.clone());
        Ok(info)
    }
    
    fn get_cpu_datas(&mut self, req: ChartInfoReq) -> Result<ChartInfoRsp>{
        // todo 合并
        Self::get_data(req, &self.history_cpu_datas)
    }
    
    fn get_mem_datas(&self, req: ChartInfoReq) -> Result<ChartInfoRsp>{
        // todo 合并
        Self::get_data(req, &self.history_mem_datas)
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

        let (history_cpu_datas, history_mem_datas) = Self::load_datas().await;

        Self {
            sys,
            cpu_datas: Vec::new(),
            mem_datas: Vec::new(),
            history_mem_datas,
            history_cpu_datas
        }
    }

    /// 加载本地数据
    async fn load_datas() -> (Vec<ChartInfo>, Vec<ChartInfo>) {
        let mut cpu_datas = Vec::new();
        let mut mem_datas = Vec::new();
        let mut path = match get_data_dir() {
            Ok(r) => {r},
            Err(_) => {
                return (cpu_datas, mem_datas);
            }
        };
        path.push(CACHE_FILE);
        if let Ok(mut file) = File::open(path).await {
            // SystemInfoCache::decode();
            let mut buf = Vec::new();
            let _ = file.read_to_end(&mut buf).await;
            if let Ok(r) = SystemInfoCache::decode(&buf[..]) {
                cpu_datas = r.cpu_datas.unwrap_or_default().infos;
                mem_datas = r.mem_datas.unwrap_or_default().infos;
            }
        }

        (cpu_datas, mem_datas)
    }

    /// 追加cpu历史数据
    fn add_cpu_info(&mut self, info: ChartInfo) {
        self.cpu_datas.push(info);
    }

    /// 追加memory历史数据
    fn add_mem_info(&mut self, info: ChartInfo) {
        self.mem_datas.push(info);
    }   
    
    /// 获取一定范围内的数据
    fn get_data(req: ChartInfoReq, datas: &Vec<ChartInfo>) -> Result<ChartInfoRsp> {
        let start = match find_index(req.start_time, datas){
            None => {
                return Ok(ChartInfoRsp::default());
            }
            Some(r) => {r}
        };
        let end = match find_index(req.end_time, datas) {
            None => {
                return Ok(ChartInfoRsp::default());
            }
            Some(r) => r,
        };

        if start>= end {
            return Ok(ChartInfoRsp::default());
        }

        Ok(
            ChartInfoRsp{
                infos: datas.iter().skip(start).take(end-start).cloned().collect(),
            }
        )
    }
}

impl Drop for SystemInfoService {
    fn drop(&mut self) {
        let mut path = match get_data_dir() {
            Ok(r) => {r},
            Err(e) => {
                error!("保存system_info数据失败{e}");
                return;
            }
        };
        path.push(CACHE_FILE);

        let cache = SystemInfoCache {
            mem_datas: Some(ChartInfoRsp {
                infos: self.mem_datas.clone(),
            }),
            cpu_datas: Some(ChartInfoRsp {
                infos: self.cpu_datas.clone(),
            }),
        };

        let buf = cache.encode_to_vec();
        if let Ok(mut file) = std::fs::File::create(path) {
            let _ = file.write_all(&buf);
        }
    }
}

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
            end = mid - 1;
            if mid - 1 > 0 && data > datas[mid - 1].timestamp {
                break;
            }
        } else if data > datas[mid].timestamp {
            start = mid + 1;
            if mid + 1 < datas.len() && data < datas[mid + 1].timestamp {
                break
            }
        } else {
            break;
        }
    }

    Some(mid)
}

#[derive(Debug)]
struct Point {
    x: u32,
    y: f64,
}

#[derive(Debug)]
struct LineEquation {
    k: f64,
    b: f64
}

impl LineEquation {
    fn new(p1: Point, p2: Point) -> Option<Self> {
        if p2.x == p1.x {
            return None;
        }
        let k = (p2.y - p1.y) / (p2.x - p1.x) as f64;
        let b = p1.y - k*p1.x as f64;

        Some(Self {
            k, b
        })
    }

    fn cal_distance(&self, p: Point) -> f64 {
        let divisor  = (self.k * p.x as f64 - p.y + self.b).abs();
        let dividend = (1.0 + self.k*self.k).inv_sqrt64();
        
        divisor * dividend
    }
}

mod test {
    use fast_inv_sqrt::{InvSqrt32, InvSqrt64};
    use crate::messages::system_info::ChartInfo;
    use crate::service::system_info::{find_index, LineEquation, Point};

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
        let p1 = Point{
            x: 10, y:5.0
        };
        let p2 = Point {
            x: 100, y: 3.0
        };

        let r = LineEquation::new(p1, p2).unwrap();
        eprintln!("{r:?}");
        let r2 = r.cal_distance(Point{
            x:100,
            y: 10.0
        });
        assert!((r.k - -0.022).abs() < 0.001);
        eprintln!("{r2}");
        assert!((r2-6.998).abs() < 0.1);
    }
    
    #[test]
    fn sqrt() {
        let x= 1600.01f32;
        eprintln!("{}, {}", x.inv_sqrt32(), 1.0 / x.sqrt());
        assert!((x.inv_sqrt32() - 1.0/x.sqrt()).abs() < 0.01);
    }
}