use std::{env, fs, io, path::absolute};

use anyhow::{Context, Result};
use clap::{Parser, Subcommand, command};
use defold_nvim_core::{
    focus::{focus_game, focus_neovim},
    mobdap, neovide, project,
};
use tracing::Level;
use tracing_appender::rolling::never;
use tracing_subscriber::fmt::writer::MakeWriterExt;

use crate::plugin_config::{LauncherType, PluginConfig, SocketType};

mod launcher;
mod plugin_config;
mod utils;

#[derive(Parser, Debug)]
// #[command(version)]
struct Args {
    #[arg(long = "debug")]
    debug: bool,

    #[command(subcommand)]
    cmd: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Open a file in Neovim or launch a new instance
    LaunchNeovim {
        #[arg(long = "launcher-type")]
        launcher_type: Option<LauncherType>,

        #[arg(long = "socket-type")]
        socket_type: Option<SocketType>,

        #[arg(long = "executable")]
        executable: Option<String>,

        #[arg(long = "extra-arguments", value_delimiter = ' ', num_args = 0..)]
        extra_arguments: Option<Vec<String>>,

        #[arg(long = "terminal-class-argument")]
        terminal_class_argument: Option<String>,

        #[arg(long = "terminal-run-argument")]
        terminal_run_argument: Option<String>,

        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,

        #[clap(value_name = "FILE", index = 2)]
        file: String,

        #[clap(value_name = "LINE", index = 3)]
        line: Option<usize>,
    },
    /// Focus the currently open instance of Neovim
    FocusNeovim {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
    /// Focus the game
    FocusGame {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
    /// Downloads Neovide
    DownloadNeovide,
    /// Downloads Mobdap Debugger
    DownloadMobdap,
    /// Install dependencies
    InstallDependencies {
        #[clap(long = "force-redownload")]
        force_redownload: bool,

        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    let logs = dirs::cache_dir()
        .context("could not get cache dir")?
        .join("defold.nvim")
        .join("logs");

    fs::create_dir_all(&logs)?;

    let (stdout, _stdout_guard) = tracing_appender::non_blocking(io::stdout());
    let (logfile, _logfile_guard) = tracing_appender::non_blocking(never(logs, "bridge.log"));

    let writer = stdout.and(logfile);

    tracing_subscriber::fmt()
        .with_file(true)
        .with_line_number(true)
        .with_max_level(if args.debug {
            Level::DEBUG
        } else {
            Level::INFO
        })
        .with_writer(writer)
        .init();

    tracing::info!("Starting defold.nvim bridge",);
    tracing::debug!("CLI: {}", env::args().collect::<Vec<String>>().join(" "));
    tracing::debug!("Clap: {args:?}");

    match args.cmd {
        Commands::LaunchNeovim {
            launcher_type,
            socket_type,
            executable,
            extra_arguments,
            terminal_class_argument,
            terminal_run_argument,
            game_root_dir,
            file,
            line,
        } => launcher::run(
            PluginConfig {
                launcher_type,
                socket_type,
                executable,
                extra_arguments,
                terminal_class_argument,
                terminal_run_argument,
            },
            absolute(game_root_dir)?,
            &absolute(file)?,
            line,
        )?,
        Commands::FocusNeovim { game_root_dir } => focus_neovim(absolute(game_root_dir)?)?,
        Commands::FocusGame { game_root_dir } => focus_game(absolute(game_root_dir)?)?,
        Commands::DownloadNeovide => {
            let path = neovide::update_or_install()?;
            tracing::info!("Installed neovide at {path:?}");
        }
        Commands::DownloadMobdap => {
            let path = mobdap::update_or_install()?;
            tracing::info!("Installed mobdap at {path:?}");
        }
        Commands::InstallDependencies {
            force_redownload,
            game_root_dir,
        } => {
            project::install_dependencies(&absolute(game_root_dir)?, force_redownload)?;
            tracing::info!("Installed dependencies");
        }
    }

    Ok(())
}
