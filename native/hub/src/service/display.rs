#[cfg(target_os = "windows")]
pub mod display_os {
    use crate::common::global_data::GlobalData;
    use crate::messages::common::UintFiveMsg;
    use crate::messages::display::{
        DisplayInfoMsg, DisplayInfoReqMsg, GetDisplayModeRspMsg, GetWallpaperRspMsg, SystemModeMsg,
    };
    use crate::service::service::{ImmService, LazyService, Service};
    use crate::{async_func_notype, async_func_typeno, func_end, func_notype, func_typeno};
    use anyhow::{anyhow, Error, Result};
    use async_trait::async_trait;
    use ddc::{Ddc, VcpValue};
    use ddc_winapi::Monitor;
    use serde::{Deserialize, Serialize};
    use std::path::PathBuf;
    use tokio_stream::wrappers::ReadDirStream;
    use tokio_stream::StreamExt;
    use winreg::enums::{KEY_READ, KEY_WRITE};
    use winreg::RegKey;

    /// 显示器亮度调节
    pub struct DisplayLight {}
    
    
    #[async_trait]
    impl ImmService for DisplayLight {
        async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
            func_notype!(self, func, get_all_devices);
            func_typeno!(self, func, req_data, set_light, DisplayInfoMsg);

            func_end!(func)
        }
    }

    impl DisplayLight {
        pub fn new() -> Self {
            Self {}
        }

        fn get_all_devices(&self) -> Result<DisplayInfoReqMsg> {
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
                .map(|(d, v)| DisplayInfoMsg {
                    screen: d,
                    value: v as u32,
                })
                .collect();
            let result = DisplayInfoReqMsg {
                infos: display_infos,
            };
            Ok(result)
        }

        fn set_light(&self, display_info: DisplayInfoMsg) -> Result<()> {
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

    const MARK: &str = "displayMode_systemMode";
    #[derive(Debug, Serialize, Deserialize, Default)]
    struct SystemModeData {
        enabled: bool,
        keep_screen: bool,
    }

    /// 显示壁纸
    pub struct DisplayMode {
        theme_reg: RegKey,
        global_data: GlobalData,
        system_mode: SystemModeData,
    }

    #[async_trait]
    impl Service for DisplayMode {
        async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
            func_notype!(
                self,
                func,
                get_current_mode,
                get_system_color,
                get_system_mode
            );
            async_func_notype!(self, func, get_wallpaper);
            async_func_typeno!(self, func, req_data, set_system_mode, SystemModeMsg);
            func_typeno!(
                self,
                func,
                req_data,
                set_mode,
                crate::messages::display::DisplayModeMsg
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
    const ES_CONTINUOUS: u32 = 0x80000000;
    const ES_DISPLAY_REQUIRED: u32 = 0x00000002;
    const ES_SYSTEM_REQUIRED: u32 = 0x00000001;
    impl DisplayMode {
        // 执行阻止系统睡眠任务
        async fn block_system(&mut self) {
            if !self.system_mode.enabled {
                Self::clear_keep();
            } else if self.system_mode.keep_screen {
                Self::keep_screen_light();
            } else {
                Self::keep_system();
            }

        }
        // 参考文档：https://learn.microsoft.com/zh-cn/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate
        // 设置系统不休眠
        fn keep_system() {
            unsafe {
                winapi::um::winbase::SetThreadExecutionState(ES_SYSTEM_REQUIRED | ES_CONTINUOUS);
            }
        }

        // 设置屏幕不关闭
        fn keep_screen_light() {
            unsafe {
                winapi::um::winbase::SetThreadExecutionState(ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED | ES_CONTINUOUS);
            }
        }

        fn clear_keep() {
            unsafe {
                winapi::um::winbase::SetThreadExecutionState(ES_CONTINUOUS);
            }
        }
    }

    impl DisplayMode {
        pub async fn new(global_data: GlobalData) -> Self {
            let hklm = RegKey::predef(winreg::enums::HKEY_CURRENT_USER);
            let system_mode = global_data
                .get_data(MARK.to_string())
                .await
                .unwrap_or(SystemModeData::default());

            let mut this = Self {
                theme_reg: hklm,
                global_data,
                system_mode,
            };
            this.block_system().await;
            this
        }

        fn get_system_mode(&self) -> Result<SystemModeMsg> {
            Ok(SystemModeMsg {
                enabled: self.system_mode.enabled,
                keep_screen: self.system_mode.keep_screen,
            })
        }

        async fn set_system_mode(&mut self, mode: SystemModeMsg) -> Result<()> {
            let mode = SystemModeData {
                enabled: mode.enabled,
                keep_screen: mode.keep_screen,
            };
            self.global_data.set_data(MARK.to_string(), &mode).await?;
            self.system_mode = mode;
            self.block_system().await;
            Ok(())
        }

        /// 获取系统颜色信息 返回 ARGB
        fn get_system_color(&self) -> Result<UintFiveMsg> {
            let hklm = RegKey::predef(winreg::enums::HKEY_CURRENT_USER);
            let color =
                hklm.open_subkey_with_flags("Software\\Microsoft\\Windows\\DWM", KEY_READ)?;
            let v: u32 = color.get_value("ColorizationColor")?;
            Ok(UintFiveMsg { value: v })
        }

        fn get_current_mode(&self) -> Result<GetDisplayModeRspMsg> {
            let theme = &self.theme_reg;
            let v: u32 = theme.get_value("SystemUsesLightTheme")?;
            let mode = crate::messages::display::DisplayModeMsg { is_light: v == 1 };
            Ok(GetDisplayModeRspMsg { mode })
        }

        fn set_mode(&self, mode: crate::messages::display::DisplayModeMsg) -> Result<()> {
            let theme = &self.theme_reg;
            let value = if mode.is_light { 1u32 } else { 0u32 };
            theme.set_value("SystemUsesLightTheme", &value)?;
            theme.set_value("AppsUseLightTheme", &value)?;

            Ok(())
        }

        async fn get_wallpaper(&self) -> Result<GetWallpaperRspMsg> {
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
                        return Ok(GetWallpaperRspMsg {
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
                        return Ok(GetWallpaperRspMsg {
                            light_wallpaper: path.clone(),
                            dark_wallpaper: path,
                        });
                    }
                }
            }

            Err(Error::msg("无法找到对应的图片"))
        }
    }

    impl Drop for DisplayMode {
        fn drop(&mut self) {
            Self::clear_keep();
        }
    }
}

#[cfg(target_os = "linux")]
pub mod display_os {
    use crate::common::global_data::GlobalData;
    use crate::common::APP_NAME;
    use crate::dbus::power_manager::OrgFreedesktopPowerManagementInhibit;
    use crate::dbus::wallpaper::OrgKdePlasmaShell;
    use crate::messages::common::UintFiveMsg;
    use crate::messages::display::{
        DisplayInfoMsg, DisplayInfoReqMsg, GetDisplayModeRspMsg, GetWallpaperRspMsg,
        SystemModeMsg,
    };
    use crate::service::service::{Service};
    use crate::{async_func_notype, async_func_typeno, func_end, func_notype, func_typeno};
    use ahash::{HashMap, HashMapExt};
    use anyhow::{Error, Result};
    use async_trait::async_trait;
    use dbus::arg::RefArg;
    use dbus::nonblock::{Proxy, SyncConnection};
    use dbus_tokio::connection;
    use ddc::Ddc;
    use ddc_i2c::I2cDeviceDdc;
    use log::error;
    use prost::Msg;
    use std::path::PathBuf;
    use std::sync::Arc;
    use std::time::Duration;
    use tokio::fs::{read_dir, File};
    use tokio::io::AsyncReadExt;
    use tokio_stream::wrappers::ReadDirStream;
    use tokio_stream::StreamExt;
    use xdg::BaseDirectories;
    use crate::dbus::screensaver::OrgFreedesktopScreenSaver;

    // DRM位置
    const DRM_PATH: &str = "/sys/class/drm/";
    /// 显示器亮度调节
    pub struct DisplayLight {
        devices: HashMap<String, I2cDeviceDdc>,
    }

    #[async_trait]
    impl Service for DisplayLight {

        async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
            func_notype!(self, func, get_all_devices);
            func_typeno!(self, func, req_data, set_light, DisplayInfo);
            func_end!(func)
        }
    }
    impl DisplayLight {
        pub async fn new() -> Option<Self> {
            match Self::get_all_enable_display().await {
                Ok(r) => Some(Self { devices: r }),
                Err(e) => {
                    error!("{}", e.to_string());
                    None
                }
            }
        }

        /// 获取所有设备信息
        fn get_all_devices(&mut self) -> Result<DisplayInfoReqMsg> {
            let displays: Vec<String> = self.devices.keys().map(|k| k.to_string()).collect();
            let displays = displays
                .into_iter()
                .map(|x| DisplayInfoMsg {
                    screen: x.to_string(),
                    value: self.get_now_light(x.as_str()).unwrap_or(0) as u32,
                })
                .collect();
            let resp = DisplayInfoReqMsg { infos: displays };
            Ok(resp)
        }

        fn get_now_light(&mut self, device: &str) -> Option<u16> {
            match self.devices.get_mut(device) {
                None => {
                    error!("获取设备失败");
                    None
                }
                Some(device) => match device.get_vcp_feature(16) {
                    Ok(v) => Some(v.value()),
                    Err(_) => {
                        error!("获取亮度失败");
                        None
                    }
                },
            }
        }

        /// 设置亮度
        fn set_light(&mut self, display: DisplayInfoMsg) -> Result<()> {
            match self.devices.get_mut(&display.screen) {
                None => {
                    error!("获取设备失败");
                }
                Some(device) => {
                    if let Err(e) = device.set_vcp_feature(16, display.value as u16) {
                        error!("设置亮度失败: {}", e.to_string());
                    }
                }
            };
            Ok(())
        }

        /// 获取所有已经启用的显示卡
        async fn get_all_enable_display() -> Result<HashMap<String, I2cDeviceDdc>> {
            // 获取所有可用的card
            let mut cards = Vec::new();
            let entries = match read_dir(DRM_PATH).await {
                Ok(en) => en,
                Err(_) => {
                    return Err(Error::msg("无法获取信息，是否加载i2c-dev模块？"));
                }
            };
            let mut entries = tokio_stream::wrappers::ReadDirStream::new(entries);
            let mut tmp_content = String::new();
            while let Some(Ok(entry)) = entries.next().await {
                let file_name = entry.file_name();
                let file_name = file_name.to_str().unwrap();
                if file_name.starts_with("card") && file_name.contains("-") {
                    let mut path = entry.path();
                    path.push("enabled");
                    if let Ok(mut file) = File::open(path).await {
                        tmp_content.clear();
                        if file.read_to_string(&mut tmp_content).await.is_ok() && tmp_content.trim() == "enabled" {
                            cards.push(entry);
                        }
                    }
                }
            }

            // 获取设备路由
            let mut result = HashMap::new();
            for entry in cards {
                let file_name = entry.file_name();
                let file_name = file_name.to_str().unwrap();
                let (_, display_name) = file_name.split_once("-").unwrap();
                let entries = read_dir(entry.path()).await?;
                let mut entries = tokio_stream::wrappers::ReadDirStream::new(entries);
                while let Some(Ok(entry)) = entries.next().await {
                    let file_name = entry.file_name();
                    let name = file_name.to_str().unwrap();
                    if name.starts_with("i2c") {
                        let ddc = ddc_i2c::from_i2c_device(format!("/dev/{name}"))?;
                        result.insert(display_name.to_owned(), ddc);
                        break;
                    }
                }
            }

            anyhow::Ok(result)
        }
    }

    const POWER_MARK: &str = "displayMode:powerManage:linux";
    const SCREENSAVER_MARK: &str = "displayMode:screensaverManage:linux";
    /// 显示壁纸
    pub struct DisplayMode {
        // 持久化存储
        global_data: GlobalData,
        theme_mode_path: String,
        proxy: Proxy<'static, Arc<SyncConnection>>,
        // 电源管理
        power_manage_proxy: Proxy<'static, Arc<SyncConnection>>,
        // 阻止锁屏
        screen_saver_manage_proxy: Proxy<'static, Arc<SyncConnection>>,
        // 电源id
        power_id: Option<u32>,
        // 锁屏id
        screen_saver_id: Option<u32>,
    }

    #[async_trait]
    impl Service for DisplayMode {

        async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>> {
            func_notype!(self, func, get_system_mode);
            async_func_notype!(
                self,
                func,
                get_wallpaper,
                get_current_mode,
                get_system_color
            );
            async_func_typeno!(
                self,
                func,
                req_data,
                set_mode,
                crate::messages::display::DisplayMode,
                set_system_mode,
                SystemModeMsg
            );
            func_end!(func)
        }
    }

    impl DisplayMode {
        pub async fn new(global_data: GlobalData) -> Result<Self> {
            // 1. 获取主题颜色
            let mut xdg = BaseDirectories::new()?.get_config_home();
            xdg.push("kdedefaults");
            xdg.push("package");

            // 2. 连接dbus
            let (resource, conn) = connection::new_session_sync()?;
            tokio::spawn(async {
                let err = resource.await;
                error!("Lost connection to D-Bus: {}", err);
            });

            let proxy = Proxy::new(
                "org.kde.plasmashell",
                "/PlasmaShell",
                Duration::from_secs(2),
                conn.clone(),
            );

            let power_manage_proxy = Proxy::new(
                "org.freedesktop.PowerManagement.Inhibit",
                "/org/freedesktop/PowerManagement/Inhibit",
                Duration::from_secs(2),
                conn.clone(),
            );

            let screen_saver_manage_proxy = Proxy::new(
                "org.freedesktop.ScreenSaver",
                "/org/freedesktop/ScreenSaver",
                Duration::from_secs(2),
                conn,
            );

            // 加载是否休眠设置
            let enabled: bool = global_data.get_data(POWER_MARK.to_string()).await.unwrap_or_default();
            let mut this = Self {
                theme_mode_path: xdg.to_str().unwrap().to_string(),
                global_data,
                proxy,
                power_manage_proxy,
                screen_saver_manage_proxy,
                power_id: None,
                screen_saver_id: None
            };
            if enabled {
                // 忽略执行错误
                let _ = this.inhabit().await;
            }

            Ok(this)
        }

        /// 获取系统颜色信息 返回 ARGB
        async fn get_system_color(&self) -> Result<UintFiveMsg> {
            let color = self.proxy.color().await?;
            Ok(UintFiveMsg { value: color })
        }

        /// 设置显示模式
        async fn set_mode(&self, req: crate::messages::display::DisplayModeMsg) -> Result<()> {
            let mut cmd = tokio::process::Command::new("plasma-apply-lookandfeel");
            cmd.arg("-a");

            if req.is_light {
                cmd.arg("org.kde.breeze.desktop");
            } else {
                cmd.arg("org.kde.breezedark.desktop");
            }

            let result = cmd.status().await?;
            if !result.success() {
                Err(Error::msg("切换模式失败"))
            } else {
                Ok(())
            }
        }

        /// 获取当前模式
        async fn get_current_mode(&self) -> Result<GetDisplayModeRspMsg> {
            let file = &self.theme_mode_path;
            let r = match tokio::fs::read_to_string(file).await {
                Ok(data) => !data.contains("dark"),
                Err(e) => {
                    return Err(Error::msg(format!("读取数据失败:{}", e)));
                }
            };

            Ok(GetDisplayModeRspMsg {
                mode: Some(crate::messages::display::DisplayModeMsg { is_light: r }),
            })
        }

        /// 获取壁纸
        async fn get_wallpaper(&self) -> Result<GetWallpaperRspMsg> {
            let proxy = &self.proxy;
            let reply = proxy.wallpaper(0).await?;
            let image = reply.get("Image");
            if image.is_none() {
                return Err(Error::msg("没有壁纸信息"));
            }

            let image = image.unwrap().as_str().unwrap();
            let mut path = PathBuf::from(image);
            // 非文件夹直接返回
            if !path.is_dir() {
                return Ok(GetWallpaperRspMsg {
                    light_wallpaper: image.to_string(),
                    dark_wallpaper: image.to_string(),
                });
            }
            // 文件夹读取
            path.push("contents");
            path.push("images");
            let light = Self::read_first_pic(&path).await?;
            path.pop();
            path.push("images_dark");
            let dark = Self::read_first_pic(&path).await?;

            Ok(GetWallpaperRspMsg {
                light_wallpaper: light,
                dark_wallpaper: dark,
            })
        }

        /// 读取指定文件夹下第一个图片格式文件
        async fn read_first_pic(path_buf: &PathBuf) -> Result<String> {
            let dir = read_dir(path_buf).await?;
            let mut entries = ReadDirStream::new(dir);
            while let Some(Ok(entry)) = entries.next().await {
                let file = entry.path();
                let file = file.to_str().unwrap();
                if file.ends_with(".jpg") || file.ends_with(".png") || file.ends_with(".webp") {
                    return Ok(file.to_string());
                }
            }

            Err(Error::msg("无法找到图片"))
        }

        /// 获取休眠模式
        fn get_system_mode(&self) -> Result<SystemModeMsg> {
            let enabled = self.power_id.is_some() || self.screen_saver_id.is_some();
            Ok(SystemModeMsg {
                enabled,
                // linux下不实现屏幕保持
                keep_screen: self.screen_saver_id.is_some(),
            })
        }

        /// 设置系统休眠模式
        async fn set_system_mode(&mut self, mode: SystemModeMsg) -> Result<()> {
            self.global_data.set_data(POWER_MARK.to_string(), &mode.enabled).await?;
            self.global_data.set_data(SCREENSAVER_MARK.to_string(), &mode.keep_screen).await?;
            if mode.enabled && !mode.keep_screen {
                self.un_inhibit_screen_saver().await?;
                self.inhabit().await?;
            } else if mode.enabled && mode.keep_screen {
                self.inhibit_screen_saver().await?;
                self.inhabit().await?;
            } else {
                self.un_inhibit_screen_saver().await?;
                self.un_inhabit().await?;
            }

            Ok(())
        }

    }

    impl DisplayMode {
        // 禁止系统休眠
        async fn inhabit(&mut self) -> Result<()> {
            if self.power_id.is_some() {
                // 已经启用了，不需要执行操作
                return Ok(());
            }

            let v = OrgFreedesktopPowerManagementInhibit::inhibit(&self
                .power_manage_proxy, APP_NAME, "程序设置为保持休眠")
                .await?;
            self.power_id = Some(v);
            Ok(())
        }
        // 取消禁止系统休眠
        async fn un_inhabit(&mut self) -> Result<()> {
            if let Some(id) = self.power_id {
                OrgFreedesktopPowerManagementInhibit::un_inhibit(&self.power_manage_proxy, id).await?;
                self.power_id = None;
            }
            Ok(())
        }
        // 启用禁止锁屏
        async fn inhibit_screen_saver(&mut self) -> Result<()> {
            if self.screen_saver_id.is_some() {
                // 已经启用了，不需要执行操作
                return Ok(());
            }
            let v = OrgFreedesktopScreenSaver::inhibit(&self.screen_saver_manage_proxy, APP_NAME, "程序设置为禁止锁屏").await?;
            self.screen_saver_id = Some(v);
            Ok(())
        }
        // 取消禁止锁屏
        async fn un_inhibit_screen_saver(&mut self) -> Result<()> {
            if let Some(id) = self.screen_saver_id {
                OrgFreedesktopScreenSaver::un_inhibit(&self.screen_saver_manage_proxy, id).await?;
                self.screen_saver_id = None;
            }
            Ok(())
        }
    }
}


#[allow(unused_imports)]
#[cfg(target_os = "linux")]
mod tests {
    use std::time::Duration;
    use dbus::nonblock::Proxy;
    use dbus_tokio::connection;
    use log::error;
    use tokio::time::sleep;

    #[tokio::test]
    async fn test() {

        let (resource, conn) = connection::new_session_sync().unwrap();
        tokio::spawn(async {
            let err = resource.await;
            error!("Lost connection to D-Bus: {}", err);
        });
        let power_manage_proxy = Proxy::new(
            "org.freedesktop.PowerManagement.Inhibit",
            "/org/freedesktop/PowerManagement/Inhibit",
            Duration::from_secs(2),
            conn,
        );
        
        sleep(Duration::from_secs(3)).await;
    }
}