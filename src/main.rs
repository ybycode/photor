#[macro_use]
extern crate log;

use env_logger::Env;

pub mod checksum;
pub mod cli;
pub mod commands;
pub mod database;
pub mod files;
pub mod models;
pub mod photoexif;

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    // if no environment variables are set to define the log level, "info" is the value by default.
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();

    cli::run().await
}
