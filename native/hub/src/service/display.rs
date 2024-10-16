#[cfg(target_os = "windows")]
pub mod display {
    use crate::messages::display::{
        DisplayInfo, DisplayInfoResponse, GetDisplayModeRsp, GetWallpaperRsp,
    };
    use crate::service::service::{ImmService, LazyService, Service};
    use crate::{async_func_notype, func_end, func_notype, func_typeno};
    use anyhow::{anyhow, Error, Result};
    use async_trait::async_trait;
    use ddc::{Ddc, VcpValue};
    use ddc_winapi::Monitor;
    use prost::Message;
    use std::path::PathBuf;
    use tokio_stream::wrappers::ReadDirStream;
    use tokio_stream::StreamExt;
    use winreg::enums::{KEY_READ, KEY_WRITE};
    use winreg::RegKey;

    /// 显示器亮度调节
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
                None => Err(anyhow!("无法找到显示器 {}", display_info.screen)),
            }
        }
    }

    /// 显示壁纸
    pub struct DisplayMode {
        theme_reg: RegKey,
    }

    #[async_trait]
    impl Service for DisplayMode {
        fn get_service_name(&self) -> &'static str {
            "DisplayMode"
        }

        async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
            func_notype!(self, func, get_current_mode);
            async_func_notype!(self, func, get_wallpaper);
            func_typeno!(
                self,
                func,
                req_data,
                set_mode,
                crate::messages::display::DisplayMode
            );
            func_end!(func)
        }
    }

    #[async_trait]
    impl LazyService for DisplayMode {
        async fn lazy_init_self(&mut self) -> Result<()> {
            let theme = self.theme_reg.open_subkey_with_flags(
                "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                KEY_WRITE | KEY_READ,
            )?;
            self.theme_reg = theme;
            Ok(())
        }
    }

    impl DisplayMode {
        pub fn new() -> Self {
            let hklm = RegKey::predef(winreg::enums::HKEY_CURRENT_USER);
            Self { theme_reg: hklm }
        }

        fn get_current_mode(&self) -> Result<GetDisplayModeRsp> {
            let theme = &self.theme_reg;
            let v: u32 = theme.get_value("SystemUsesLightTheme")?;
            let mode = crate::messages::display::DisplayMode { is_light: v == 1 };
            Ok(GetDisplayModeRsp { mode: Some(mode) })
        }

        fn set_mode(&self, mode: crate::messages::display::DisplayMode) -> Result<()> {
            let theme = &self.theme_reg;
            let value = if mode.is_light { 1u32 } else { 0u32 };
            theme.set_value("SystemUsesLightTheme", &value)?;
            theme.set_value("AppsUseLightTheme", &value)?;

            Ok(())
        }

        async fn get_wallpaper(&self) -> Result<GetWallpaperRsp> {
            let appdata = match std::env::var("APPDATA") {
                Ok(v) => v,
                Err(_) => {
                    return Err(Error::msg("无法获取APPDATA环境变量"));
                }
            };
            let mut dir = PathBuf::from(appdata);
            dir.push("Microsoft\\Windows\\Themes\\CachedFiles");
            if dir.is_dir() {
                let dir = tokio::fs::read_dir(dir).await?;
                let mut entries = ReadDirStream::new(dir);
                while let Some(Ok(entry)) = entries.next().await {
                    let file = entry.file_name();
                    let file = file.to_str().unwrap();
                    if file.ends_with(".jpg") {
                        let path = entry.path().to_str().unwrap().to_string();
                        return Ok(GetWallpaperRsp {
                            light_wallpaper: path.clone(),
                            dark_wallpaper: path,
                        });
                    }
                }
            } else {
                dir.pop();
                let dir = tokio::fs::read_dir(dir).await?;
                let mut entries = ReadDirStream::new(dir);
                while let Some(Ok(entry)) = entries.next().await {
                    let file = entry.file_name();
                    let file = file.to_str().unwrap();
                    if file.starts_with("Transcoded") {
                        let path = entry.path().to_str().unwrap().to_string();
                        return Ok(GetWallpaperRsp {
                            light_wallpaper: path.clone(),
                            dark_wallpaper: path,
                        });
                    }
                }
            }

            Err(Error::msg("无法找到对应的图片"))
        }
    }
}

#[cfg(target_os = "linux")]
pub mod display {

    /// 显示器亮度调节
    pub struct DisplayLight {}
    /// 显示壁纸
    pub struct DisplayMode {}
}