//! This `hub` crate is the
//! entry point of the Rust logic.

mod common;
mod messages;

use std::time::Duration;
use messages::basic::*;
use rinf::debug_print;
use crate::common::*;
use tokio;

rinf::write_interface!();

async fn main() {
    debug_print!("Hello, world!12");
    debug_print!("Hello, world!12");
    tokio::spawn(communicate());
    tokio::spawn(send());
    debug_print!("Hello, world!");
}

async fn communicate() -> Result<()> {
    // Send signals to Dart like below.
    let mut receiver = Request::get_dart_signal_receiver()?;

    while let Some(signal) = receiver.recv().await {
        let msg = signal.message;
        debug_print!("{:?}", msg);
    }
    
    Ok(())
}

async fn send() -> Result<()> {
    let mut num = 1;
    loop {
        tokio::time::sleep(Duration::from_secs(3)).await;
        Response { resp: num.to_string()  }.send_signal_to_dart(); // GENERATED
        num += 1;
    }
}