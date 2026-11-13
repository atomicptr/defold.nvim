use std::{
    env, fs,
    path::{PathBuf, absolute},
};

use anyhow::{Context, Result};
use clap::{ArgAction, Parser, Subcommand};
use defold_nvim_core::{
    editor,
    editor_config::{LauncherSettings, LauncherType},
    focus::{focus_game, focus_neovim},
    nvim_server::SocketType,
    path, project, script_api,
};
use tracing::Level;
use tracing_appender::rolling::never;

use crate::build_game::{Severity, build_game};

mod build_game;
mod error_dialog;
mod launcher;

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
        /// Show a native error dialog if launching fails
        #[arg(long)]
        show_error_dialog: bool,

        #[arg(long = "launcher-type")]
        launcher_type: Option<LauncherType>,

        #[arg(long = "socket-type")]
        socket_type: Option<SocketType>,

        #[arg(long = "executable")]
        executable: Option<String>,

        #[arg(long = "appname")]
        appname: Option<String>,

        #[arg(long = "run-arg", allow_hyphen_values = true)]
        run_arg: Option<String>,

        #[clap(value_name = "GAME_ROOT_DIR")]
        game_root_dir: String,

        #[clap(value_name = "FILE")]
        file: String,

        #[clap(value_name = "LINE")]
        line: Option<usize>,

        #[arg(last = true)]
        arguments: Option<Vec<String>>,
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
    /// List dependencies of game
    ListDependencies {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
    /// Finds the open editor port
    FindEditorPort {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,
    },
    /// Sends a command to the editor
    SendCommand {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,

        #[clap(value_name = "COMMAND", index = 2)]
        command: String,
    },
    /// Compile `.script_api` file and return the resulting `.lua` in stdout
    CompileScriptApi {
        #[clap(value_name = "SCRIPT_API_FILE", index = 1)]
        input: PathBuf,
    },
    BuildGame {
        #[clap(value_name = "GAME_ROOT_DIR", index = 1)]
        game_root_dir: String,

        #[arg(long = "min-severity")]
        min_severity: Severity,

        #[arg(long, action = ArgAction::SetTrue)]
        disable_logs: bool,
    },
    /// Show a sample launch error dialog
    TestErrorDialog,
    /// Print the version of this executable
    Version,
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

    let logs = path::cache_dir()?.join("logs");

    fs::create_dir_all(&logs)?;

    let (logfile, _logfile_guard) = tracing_appender::non_blocking(never(&logs, "bridge.log"));

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
            appname,
            run_arg,
            arguments,
            game_root_dir,
            file,
            line,
            show_error_dialog,
        } => {
            let result = launcher::run(
                &LauncherSettings {
                    launcher_type,
                    socket_type,
                    executable,
                    appname,
                    run_arg,
                    arguments,
                    ..Default::default()
                },
                &absolute(game_root_dir)?,
                &absolute(file)?,
                line,
            );

            if show_error_dialog
                && let Err(error) = &result
                && let Err(dialog_error) = error_dialog::show(error, Some(&logs.join("bridge.log")))
            {
                eprintln!("Could not show launch error dialog: {dialog_error}");
            }

            result?;
        }
        Commands::FocusNeovim { game_root_dir } => focus_neovim(&absolute(game_root_dir)?)?,
        Commands::FocusGame { game_root_dir } => focus_game(&absolute(game_root_dir)?)?,
        Commands::ListDependencies { game_root_dir } => {
            let root_dir = absolute(&game_root_dir)?;

            for dir in project::list_dependency_dirs(&root_dir)? {
                tracing::info!("{}", dir.display());
            }
        }
        Commands::FindEditorPort { game_root_dir } => {
            if let Some(port) = editor::find_port(&absolute(game_root_dir)?) {
                println!("Editor is running at port {port}");
            } else {
                println!("Could not find editor port, is the editor open?");
            }
        }
        Commands::SendCommand {
            game_root_dir,
            command,
        } => {
            let port = editor::find_port(&absolute(game_root_dir)?)
                .context("Could not find editor port, is the editor open?")?;

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
        Commands::BuildGame {
            game_root_dir,
            min_severity,
            disable_logs,
        } => {
            let port = editor::find_port(&absolute(game_root_dir)?)
                .context("Could not find editor port, is the editor open?")?;

            build_game(port, min_severity, !disable_logs)?;
        }
        Commands::TestErrorDialog => {
            let error = anyhow::anyhow!("This is a test error; no Neovim launch was attempted.")
                .context("Testing the launch error dialog");

            error_dialog::show(&error, Some(&logs.join("bridge.log")))?;
        }
        Commands::Version => {
            println!("{}", env!("CARGO_PKG_VERSION"));
        }
    }

    Ok(())
}
