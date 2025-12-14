use std::{env, fs, io, path::absolute};

use anyhow::{Context, Result};
use clap::{Parser, Subcommand, command};
use tracing::Level;
use tracing_appender::rolling::daily;
use tracing_subscriber::fmt::writer::MakeWriterExt;

mod launcher;
mod plugin_config;
mod utils;

#[derive(Parser, Debug)]
// #[command(version)]
struct Args {
    #[command(subcommand)]
    cmd: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    LaunchNeovim {
        #[clap(value_name = "LAUNCH_CONFIG", index = 1)]
        launch_config: String,

        #[clap(value_name = "GAME_ROOT_DIR", index = 2)]
        game_root_dir: String,

        #[clap(value_name = "FILE", index = 3)]
        file: String,

        #[clap(value_name = "LINE", index = 4)]
        line: Option<usize>,
    },
}

fn main() -> Result<()> {
    let logs = dirs::cache_dir()
        .context("could not get cache dir")?
        .join("defold.nvim")
        .join("logs");

    fs::create_dir_all(&logs)?;

    let (stdout, _stdout_guard) = tracing_appender::non_blocking(io::stdout());
    let (logfile, _logfile_guard) = tracing_appender::non_blocking(daily(logs, "bridge"));

    let writer = stdout.and(logfile);

    tracing_subscriber::fmt()
        .with_file(true)
        .with_line_number(true)
        .with_max_level(Level::DEBUG)
        .with_writer(writer)
        .init();

    tracing::info!("Starting defold.nvim bridge",);
    tracing::debug!("CLI: {}", env::args().collect::<Vec<String>>().join(" "));

    let args = Args::parse();

    tracing::debug!("Clap: {args:?}");

    match args.cmd {
        Commands::LaunchNeovim {
            launch_config,
            game_root_dir,
            file,
            line,
        } => launcher::run(
            launcher::LaunchConfig::from_file(absolute(launch_config)?)?,
            absolute(game_root_dir)?,
            absolute(file)?,
            line,
        )?,
    }

    Ok(())
}
