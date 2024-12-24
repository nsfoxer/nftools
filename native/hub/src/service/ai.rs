use reqwest_dav::re_exports::serde::Deserialize;
use futures::prelude::*;
use anyhow::Result;

#[derive(Deserialize)]
struct BaiduAiRsp {
    is_end: bool,
    is_truncated: bool,
    result: String,
}

struct BaiduAiService {

}

impl BaiduAiService {
    async fn ai() -> Result<impl Stream<Item = Result<Option<Vec<u8>>>>> {
        let client = reqwest::Client::new();
        let mut stream =client.post("https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/yi_34b_chat?access_token=24.23104fdfb30a1d1cec5560891e7bb6e0.2592000.1737605136.282335-116815013")
            .body(r#"{"messages":[{"role":"user","content":"好饿"}],"stream":true}"#)
            .send()
            .await?
            .bytes_stream();

        let result = stream_generator::generate_stream(|mut dest| async move {
            while let Some(info) = stream.next().await {
                let info = info;
                dest.send(line).await
            }
        });

        // let stream = stream.map(|x| {
        //     let x = x?;
        //     let info = String::from_utf8_lossy(x.as_ref());
        //     let info = if info.starts_with("data:") {
        //         info.trim_start_matches("data:")
        //     } else {
        //         info.as_ref()
        //     };
        //     let rsp: BaiduAiRsp = serde_json::from_str(info)?;
        //     return anyhow::Ok(rsp);
        // });

        // while let Some(item) = stream.next().await {
        //     let item = item.unwrap();
        //     let item = String::from_utf8_lossy(&item);
        //     let now: chrono::DateTime<chrono::Utc> = chrono::Utc::now();
        //     println!("{:?}",now);
        //     println!("{}", item);
        // }

        Ok(result)
    }
}