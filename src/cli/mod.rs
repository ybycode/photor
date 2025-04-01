use crate::commands::import as cmd_import;
use crate::commands::list_photos as cmd_list_photos;
use crate::database;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

// use crate::cli::{Cli, Commands};

pub mod import;
pub mod init;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// Sets a custom config file
    #[arg(short, long, value_name = "FILE")]
    pub config: Option<PathBuf>,

    /// Sets the target repository (defaults to the current directory)
    #[arg(short, long, value_name = "DIRECTORY")]
    pub repo: Option<PathBuf>,

    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Initializes a new repository
    Init(init::InitArgs),

    /// List photos
    List,

    /// Import photos from a directory
    Import(import::ImportArgs),

    /// Migrate the database
    Migrate,
}

pub async fn run() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.command {
        Some(Commands::Init(args)) => init::run(args),
        Some(Commands::Migrate) => return database::migrate().await,
        Some(Commands::List) => return cmd_list_photos::run().await,
        Some(Commands::Import(import_args)) => {
            return cmd_import::run(&import_args.directory).await;
        }

        None => (),
    };

    Ok(())
}
