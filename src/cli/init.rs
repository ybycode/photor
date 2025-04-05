use clap::Args;
use std::path::PathBuf;

#[derive(Args)]
pub struct InitArgs {
    /// The directory where to create the repository
    #[arg(short, long)]
    pub directory: Option<PathBuf>,
}

// pub fn run(opt_directory: &Option<PathBuf>) {
pub fn run(args: &InitArgs) {
    let current_dir = std::env::current_dir().expect("Failed to get the current directory");
    let dest = args.directory.as_ref().unwrap_or_else(|| &current_dir);
    println!("TODO: Initialization of a new repo in {:?}", dest);
}
