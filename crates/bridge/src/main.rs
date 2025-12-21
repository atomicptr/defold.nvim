use std::{
    env, fs,
    path::{PathBuf, absolute},
};

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use defold_nvim_core::{
    editor,
    focus::{focus_game, focus_neovim},
    mobdap, neovide, project, script_api,
};
use tracing::Level;
use tracing_appender::rolling::never;

use crate::plugin_config::{LauncherType, PluginConfig, SocketType};

mod launcher;
mod plugin_config;
mod utils;

#[derive(Parser, Debug)]
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

        #[arg(long = "terminal-class-argument")]
        terminal_class_argument: Option<String>,

        #[arg(long = "terminal-run-argument")]
        terminal_run_argument: Option<String>,

        #[clap(value_name = "GAME_ROOT_DIR")]
        game_root_dir: String,

        #[clap(value_name = "FILE")]
        file: String,

        #[clap(value_name = "LINE")]
        line: Option<usize>,

        #[arg(last = true)]
        extra_arguments: Option<Vec<String>>,
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
    /// Install dependencies for game
    InstallDependencies {
        #[clap(long = "force-redownload")]
        force_redownload: bool,

        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
    /// List dependencies of game
    ListDependencies {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
    /// Finds the open editor port
    FindEditorPort,
    /// Sends a command to the editor
    SendCommand {
        #[clap(long = "port")]
        port: Option<u16>,

        #[clap(value_name = "COMMAND", index = 1)]
        command: String,
    },
    /// Compile `.script_api` file and return the resulting `.lua` in stdout
    CompileScriptApi {
        #[clap(value_name = "SCRIPT_API_FILE", index = 1)]
        input: PathBuf,
    },
}

fn main() -> Result<()> {
    let mut err = None;

    let args = match Args::try_parse() {
        Ok(args) => Some(args),
        Err(e) => {
            err = Some(e);
            None
        }
    };

    let logs = dirs::cache_dir()
        .context("could not get cache dir")?
        .join("defold.nvim")
        .join("logs");

    fs::create_dir_all(&logs)?;

    let (logfile, _logfile_guard) = tracing_appender::non_blocking(never(logs, "bridge.log"));

    tracing_subscriber::fmt()
        .with_file(true)
        .with_line_number(true)
        .with_max_level(match &args {
            Some(args) if args.debug => Level::DEBUG,
            Some(_) => Level::INFO,
            None => Level::DEBUG,
        })
        .with_writer(logfile)
        .with_ansi(false)
        .init();

    tracing::info!("Starting defold.nvim bridge",);
    tracing::debug!("CLI: {}", env::args().collect::<Vec<String>>().join(" "));
    tracing::debug!("Clap: {args:?}");

    if let Some(err) = err {
        tracing::error!("Clap Error {}", err.to_string());
        err.exit();
    }

    let args = args.unwrap();

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
            &PluginConfig {
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
            let path = neovide::install()?;
            println!("Installed neovide at {}", path.display());
        }
        Commands::DownloadMobdap => {
            let path = mobdap::install()?;
            println!("Installed mobdap at {}", path.display());
        }
        Commands::InstallDependencies {
            force_redownload,
            game_root_dir,
        } => {
            let root_dir = absolute(&game_root_dir)?;

            project::install_dependencies(&root_dir, force_redownload)?;
            println!("Finished installing dependencies for {game_root_dir}",);
        }
        Commands::ListDependencies { game_root_dir } => {
            let root_dir = absolute(&game_root_dir)?;

            for dir in project::list_dependency_dirs(&root_dir)? {
                tracing::info!("{}", dir.display());
            }
        }
        Commands::FindEditorPort => {
            if let Some(port) = editor::find_port() {
                println!("Editor is running at port {port}");
            } else {
                println!("Could not find editor port, is the editor open?");
            }
        }
        Commands::SendCommand { port, command } => {
            editor::send_command(port, &command)?;
        }
        Commands::CompileScriptApi { input } => {
            if !input.exists() {
                println!("File {} could not be found", input.display());
                return Ok(());
            }

            let data = fs::read_to_string(input)?;
            let res = script_api::compile(&data)?;

            println!("{res}");
        }
    }

    Ok(())
}
