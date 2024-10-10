use anyhow::Result;
use async_trait::async_trait;

/// 服务
#[async_trait]
pub trait Service: Send {
    /// 服务标识
    fn get_service_name(&self) -> &'static str;
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>>;
}

/// 惰性初始化服务
#[async_trait]
pub trait LazyService: Service {
    /// 惰性初始化
    async fn lazy_init_self(&mut self) -> Result<()>;
}

/// "无状态"服务 可多请求同时处理
#[async_trait]
pub trait ImmService: Send + Sync {
    /// 服务标识
    fn get_service_name(&self) -> &'static str;

    /// 实际处理
    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>>;
}

mod macros {
    // fn func(&mut self) -> Result(());
    #[macro_export]
    macro_rules! func_nono {
    ($self:ident, $function:ident, $($name:ident),+) => {
        match $function {
        $(
        stringify!($name) => {
             $self.$name()?;
             return Ok(None);
        },
        )*
            _ =>{}
        }
    }
}
    // fn func(&mut self) -> Result(Rsp);
    #[macro_export]
    macro_rules! func_notype{
    ($self:ident, $function:ident, $($name:ident),+) => {
        match $function {
        $(
        stringify!($name) => {
            let rsp = $self.$name()?;
            let mut buf = Vec::new();
            rsp.encode(&mut buf)?;
            return Ok(Some(buf));
        },
        )*
            _ =>{}
        }
    }
}
    // fn func(&mut self, req: Req) -> Result(());
    #[macro_export]
    macro_rules! func_typeno {
    ($self:ident, $function:ident, $data:ident, $($name:ident, $req: ty),+) => {
    match $function {
        $(
        stringify!($name) => {
            let req = <$req>::decode(&$data[..])?;
            $self.$name(req)?;
            return Ok(None);
        },
        )*
            _ =>{}
        }
    }
}
    // fn func(&mut self, req: Req) -> Result(Rsp);
    #[macro_export]
    macro_rules! func_typetype {
    ($self:ident, $function:ident, $data:ident, $($name:ident, $req:ty),+) => {
    match $function {
        $(
        stringify!($name) => {
            let req = <$req>::decode(&data.unwrap()[..])?;
            let rsp = $self.$name(req)?;
            let mut buf = Vec::new();
            rsp.encode(&mut buf)?;
            return Ok(Some(buf));
        }
        )*
            _ =>{}
        }
    }
}

    // async fn func(&mut self) -> Result(());
    #[macro_export]
    macro_rules! async_func_nono {
    ($self:ident, $function:ident, $($name:ident),+) => {
        match $function {
        $(
        stringify!($name) => {
             $self.$name().await?;
             return Ok(None);
        },
        )*
            _ =>{}
        }
    }
}
    // async fn func(&mut self) -> Result(Rsp);
    #[macro_export]
    macro_rules! async_func_notype{
    ($self:ident, $function:ident, $($name:ident),+) => {
        match $function {
        $(
        stringify!($name) => {
            let rsp = $self.$name().await?;
            let mut buf = Vec::new();
            rsp.encode(&mut buf)?;
            return Ok(Some(buf));
        },
        )*
            _ =>{}
        }
    }
}
    // async fn func(&mut self, req: Req) -> Result(());
    #[macro_export]
    macro_rules! async_func_typeno {
    ($self:ident, $function:ident, $data:ident, $($name:ident, $req: ty),+) => {
    match $function {
        $(
        stringify!($name) => {
            let req = <$req>::decode(&$data[..])?;
            $self.$name(req).await?;
            return Ok(None);
        }
        )*
            _ =>{}
        }
    }
}
    // async fn func(&mut self, req: Req) -> Result(Rsp);
    #[macro_export]
    macro_rules! async_func_typetype {
    ($self:ident, $function:ident, $data:ident, $($name:ident, $req:ty),+) => {
    match $function {
        $(
        stringify!($name) => {
            let req = <$req>::decode(&data.unwrap()[..])?;
            let rsp = $self.$name(req).await?;
            let mut buf = Vec::new();
            rsp.encode(&mut buf)?;
            return Ok(Some(buf));
        }
        )*
            _ =>{}
        }
    }
}
    #[macro_export]
    macro_rules! func_end {
        ($function:ident) => {
            Err(anyhow::Error::msg(format!(
                "没有function[{}]匹配",
                $function
            )))
        };
    }
}
