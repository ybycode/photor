use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct ImportArgs {
    /// Where the files to import are
    pub directory: PathBuf,
}
