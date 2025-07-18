use anyhow::Result;
use async_trait::async_trait;
use tokio::sync::mpsc::UnboundedSender;

/// 服务
#[async_trait]
pub trait Service: Send {
    /// 处理服务
    async fn handle(&mut self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>>;
    /// 关闭服务 有退出保存数据需求在这里处理
    async fn close(&mut self) -> Result<()> {
        Ok(())
    }
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
    /// 实际处理
    async fn handle(&self, func: &str, req_data: Vec<u8>) -> Result<Option<Vec<u8>>>;
    /// 关闭服务 有退出保存数据需求在这里处理
    async fn close(&self) -> Result<()> {
        Ok(())
    }
}

/// stream响应服务,同时需要支持service
#[async_trait]
pub trait StreamService: Service  { 
    async fn handle_stream(
        &mut self,
        func: &str,
        req_data: Vec<u8>,
        tx: UnboundedSender<Result<Option<Vec<u8>>>>,
    ) -> Result<()>;
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
            let buf = rinf::serialize(&rsp)?;
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
            let req = rinf::deserialize($data.as_slice())?;
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
            let req = rinf::deserialize($data.as_slice())?;
            let rsp = $self.$name(req)?;
            let buf = rinf::serialize(&rsp)?;
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
            let buf = rinf::serialize(&rsp)?;
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
            let req = rinf::deserialize($data.as_slice())?;
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
            let req = rinf::deserialize($data.as_slice())?;
            let rsp = $self.$name(req).await?;
            let buf = rinf::serialize(&rsp)?;
            return Ok(Some(buf));
        }
        )*
            _ =>{}
        }
    }
}
    // async fn stream_func(&mut self, req: Req) -> Result(());
    #[macro_export]
    macro_rules! async_stream_func_typeno {
    ($self:ident, $function:ident, $data:ident, $($name:ident, $req: ty, $tx:ident),+) => {
    match $function {
        $(
        stringify!($name) => {
            let req = rinf::deserialize($data.as_slice())?;
            $self.$name(req, $tx).await?;
            return Ok(());
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
