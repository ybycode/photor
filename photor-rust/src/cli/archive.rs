use clap::{Args, Subcommand};

#[derive(Args)]
pub struct ArchiveNewArgs {
    /// Name of the new archive
    #[arg(long)]
    name: String,
}

#[derive(Args)]
pub struct ArchivePopulateArgs {
    /// Argument for populate
    #[arg(long)]
    arg: i32,
}

#[derive(Subcommand)]
pub enum ArchiveCommand {
    /// Create a new archive
    New(ArchiveNewArgs),
    /// Populate an archive
    Populate(ArchivePopulateArgs),
}

#[derive(Args)]
pub struct ArchiveArgs {
    #[command(subcommand)]
    pub command: ArchiveCommand,
}

pub fn match_subcommand(command: &ArchiveCommand) -> anyhow::Result<()> {
    return match command {
        ArchiveCommand::New(_args) => {
            info!("to be implemented");
            // Implementation here
            Ok(())
        }
        ArchiveCommand::Populate(_args) => {
            info!("to be implemented");
            // Implementation here
            Ok(())
        }
    };
}
