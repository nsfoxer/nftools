use crate::service::service::{ImmService, Service};
use prost::Message;


#[cfg(target_os = "windows")]
pub mod display_light {
    use async_trait::async_trait;
    use ddc::{Ddc, VcpValue};
    use ddc_winapi::Monitor;
    use crate::{func_end, func_notype, func_typeno};
    use crate::messages::display::{DisplayInfo, DisplayInfoResponse};
    use crate::service::service::ImmService;
    use anyhow::{anyhow, Result};
    use prost::Message;
    use rinf::debug_print;

    pub struct DisplayLight {}

    #[async_trait]
    impl ImmService for DisplayLight {

        fn get_service_name(&self) -> &'static str {
            "DisplayLight"
        }

        async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
            func_notype!(self, func, get_all_devices);
            func_typeno!(self, func, req_data, set_light, DisplayInfo);

            func_end!(func)
        }
    }

    impl DisplayLight {
        pub fn new() -> Self {
            Self {}
        }

        fn get_all_devices(&self) -> Result<DisplayInfoResponse> {
            let display_infos = Monitor::enumerate()
                .unwrap_or(Vec::new())
                .into_iter()
                .map(|mut x| {
                    (
                        x.description(),
                        x.get_vcp_feature(16)
                            .unwrap_or(VcpValue::from_value(0))
                            .value(),
                    )
                })
                .map(|(d, v)| DisplayInfo {
                    screen: d,
                    value: v as u32,
                })
                .collect();
            let result = DisplayInfoResponse {
                infos: display_infos,
            };
            Ok(result)
        }
        
        fn set_light(&self, display_info: DisplayInfo) -> Result<()> {
            let m = Monitor::enumerate()
                .unwrap_or(Vec::new())
                .into_iter()
                .filter(|x| x.description() == display_info.screen.as_str())
                .next();
            match m {
                Some(mut v) => {
                    v.set_vcp_feature(16, display_info.value as u16)?;
                    Ok(())
                }
                None => {
                    Err(anyhow!("无法找到显示器 {}", display_info.screen))
                }
            }
        }
    }
}

