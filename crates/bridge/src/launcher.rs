use std::{
    fs::{self},
    path::{Path, PathBuf},
    process::{Child, Command},
};

use anyhow::{Context, Result, bail};
use defold_nvim_core::{focus::focus_neovim, utils::classname};
use termlauncher::{Application, CustomTerminal, Terminal};
use which::which;

use crate::{
    neovide,
    plugin_config::{LauncherType, PluginConfig, SocketType},
    utils::{self, is_port_in_use},
};

const ERR_NEOVIDE_NOT_FOUND: &str = "Could not find Neovide, have you installed it?";
const ERR_TERMINAL_NOT_FOUND: &str = "Could not find any suitable terminal";

const VAR_CLASSNAME: &str = "{CLASSNAME}";
const VAR_ADDRESS: &str = "{ADDR}";
const VAR_LINE: &str = "{LINE}";
const VAR_FILE: &str = "{FILE}";

fn report_process_errors(child: Child) -> Result<()> {
    let output = child.wait_with_output()?;

    if !output.stdout.is_empty() {
        tracing::debug!("Proccess Out: {}", String::from_utf8(output.stdout)?);
    }

    if !output.stderr.is_empty() {
        tracing::error!("Proccess Err: {}", String::from_utf8(output.stderr)?);
    }

    Ok(())
}

fn apply_launcher_vars(launcher: &Terminal, var: &str, replace_with: &str) -> Terminal {
    match launcher {
        Terminal::Custom(term) => Terminal::Custom(CustomTerminal {
            arguments: apply_vars(&term.arguments, var, replace_with),
            ..term.clone()
        }),
        term => term.clone(),
    }
}

fn apply_vars(args: &[String], var: &str, replace_with: &str) -> Vec<String> {
    args.iter().map(|s| s.replace(var, replace_with)).collect()
}

fn create_launcher(cfg: &PluginConfig) -> Result<Terminal> {
    match cfg.launcher_type {
        Some(LauncherType::Neovide) => {
            let executable = &cfg
                .executable
                .as_ref()
                .map(Into::into)
                .or_else(|| which("neovide").ok())
                .or_else(|| match neovide::install() {
                    Ok(path) => Some(path),
                    Err(err) => {
                        tracing::error!("Could not download neovide because: {err:?}");
                        None
                    }
                })
                .context(ERR_NEOVIDE_NOT_FOUND)?;

            if !executable.exists() {
                bail!(ERR_NEOVIDE_NOT_FOUND);
            }

            let mut args = cfg.arguments.clone().unwrap_or_default();

            if cfg!(target_os = "linux") {
                args.push("--wayland_app_id".to_string());
                args.push(VAR_CLASSNAME.to_string());

                args.push("--x11-wm-class".to_string());
                args.push(VAR_CLASSNAME.to_string());
            }

            Ok(Terminal::Custom(CustomTerminal {
                executable: executable
                    .to_str()
                    .context("could not convert path to string")?
                    .to_string(),
                arguments: args,
                run_arg: Some("--neovim-bin".to_string()),
                ..Default::default()
            }))
        }
        Some(LauncherType::Terminal) => {
            // terminal specified by absolute path
            if let Some(executable) = &cfg.executable.clone().map(PathBuf::from)
                && executable.is_absolute()
                && executable.exists()
            {
                let term = Terminal::Custom(CustomTerminal {
                    executable: cfg.executable.clone().unwrap(),
                    arguments: cfg.arguments.clone().unwrap_or_default(),
                    ..Default::default()
                });

                tracing::debug!("Terminal specified by absolute path {term:?}");

                Ok(term)
            } else if let Some(exe_name) = &cfg.executable
                && let Some(term) = Terminal::find_by_name(exe_name)
                && term.is_available()
            {
                tracing::debug!("Looking for terminal by name {exe_name} found {term:?}");

                Ok(term)
            } else {
                tracing::debug!(
                    "No terminal specific terminal specified or not found, looking for available one..."
                );

                if let Some(term) = Terminal::find_available() {
                    tracing::debug!("Found {term:?}");

                    Ok(term)
                } else {
                    bail!(ERR_TERMINAL_NOT_FOUND);
                }
            }
        }
        None => {
            // lets try to create one using Neovide
            if let Ok(term) = create_launcher(&PluginConfig {
                launcher_type: Some(LauncherType::Neovide),
                ..cfg.clone()
            }) {
                return Ok(term);
            }

            // if that doesnt work try again with terminal
            if let Ok(term) = create_launcher(&PluginConfig {
                launcher_type: Some(LauncherType::Terminal),
                ..cfg.clone()
            }) {
                return Ok(term);
            }

            bail!("Could neither find Neovide nor any supported terminal")
        }
    }
}

fn nvim_open_file_remote(nvim: &str, server: &str, file: &str, line: Option<usize>) -> Result<()> {
    let remote_cmd = if let Some(line) = line {
        format!("+{line} {file}")
    } else {
        file.to_string()
    };

    tracing::debug!("Open '{remote_cmd}' via socket: {server}");

    let out = Command::new(nvim)
        .arg("--server")
        .arg(server)
        .arg("--remote-send")
        .arg(format!("\"<C-\\\\><C-n>:edit {remote_cmd}<CR>\""))
        .output()?;

    if !out.stderr.is_empty() {
        bail!(String::from_utf8(out.stderr)?);
    }

    Ok(())
}

fn run_fsock(
    launcher: &Terminal,
    app: Application,
    nvim: &str,
    root_dir: &Path,
    file: &str,
    line: Option<usize>,
) -> Result<()> {
    let socket_file = utils::runtime_dir(
        root_dir
            .to_str()
            .context("could not convert path to string")?,
    )?
    .join("neovim.sock");

    tracing::debug!("Using fsock at {socket_file:?}");

    let mut app = app;

    app.args = apply_vars(
        &app.args,
        VAR_ADDRESS,
        socket_file
            .to_str()
            .context("could not convert socket file to string")?,
    );

    if socket_file.exists() {
        // if we couldnt communicate with the server despite existing apparently
        // delete it and start a new instance
        if let Err(err) = nvim_open_file_remote(
            nvim,
            socket_file
                .to_str()
                .context("could not convert path to string")?,
            file,
            line,
        ) {
            tracing::error!("Failed to communicate with neovim server: {err:?}");

            fs::remove_file(socket_file)?;
            report_process_errors(app.launch_with(launcher)?)?;
        }

        return Ok(());
    }

    report_process_errors(app.launch_with(launcher)?)?;
    Ok(())
}

fn run_netsock(
    launcher: &Terminal,
    mut app: Application,
    nvim: &str,
    root_dir: &Path,
    file: &str,
    line: Option<usize>,
) -> Result<()> {
    let port_file = utils::runtime_dir(
        root_dir
            .to_str()
            .context("could not convert path to string")?,
    )?
    .join("port");

    let port: u16 = if port_file.exists() {
        fs::read_to_string(&port_file)?.parse()?
    } else {
        utils::find_free_port()
    };

    let socket = format!("127.0.0.1:{port}");

    tracing::debug!("Trying to use netsock with port {socket}");

    if is_port_in_use(port) {
        // if we couldnt communicate with the server despite existing apparently
        // delete it and start a new instance
        if let Err(err) = nvim_open_file_remote(nvim, &socket, file, line) {
            tracing::error!("Failed to communicate with neovim server: {err:?}");

            let new_port = utils::find_free_port();
            let socket = format!("127.0.0.1:{new_port}");
            tracing::debug!("Trying to use netsock with port {socket}");
            fs::write(port_file, new_port.to_string())?;

            app.args = apply_vars(&app.args, VAR_ADDRESS, &socket);
            report_process_errors(app.launch_with(launcher)?)?;
        }

        return Ok(());
    }

    fs::write(port_file, port.to_string())?;
    app.args = apply_vars(&app.args, VAR_ADDRESS, &socket);
    report_process_errors(app.launch_with(launcher)?)?;

    Ok(())
}

pub fn run(
    plugin_config: &PluginConfig,
    root_dir: PathBuf,
    file: &Path,
    line: Option<usize>,
) -> Result<()> {
    let nvim = which("nvim")?
        .to_str()
        .context("could not convert nvim path to string")?
        .to_string();

    let mut launcher = create_launcher(plugin_config)?;

    let mut app = Application::new(&nvim)
        .with_arg("--listen")
        .with_arg(VAR_ADDRESS)
        .with_arg("--remote")
        .with_arg(VAR_LINE)
        .with_arg(VAR_FILE);

    #[cfg(target_os = "linux")]
    {
        let class = &classname(
            root_dir
                .to_str()
                .context("could not convert path to string")?,
        )?;

        app = app.with_class(class);

        // if is custom replace it in their args too
        launcher = if let Terminal::Custom(_) = launcher {
            apply_launcher_vars(&launcher, VAR_CLASSNAME, class)
        } else {
            launcher
        };
    }

    let file_str = file.to_str().context("could not convert path to string")?;

    let mut app = if let Some(line) = line {
        app.args = apply_vars(&app.args, VAR_LINE, &format!("+{line}"));
        app
    } else {
        app.args.retain(|s| *s != VAR_LINE);
        app
    };

    app.args = apply_vars(&app.args, VAR_FILE, file_str);

    // due to Neovide having both a run argument with "--neovim-bin" and using the "--" separator
    // we kinda need to prepend this to the application
    if matches!(plugin_config.launcher_type, Some(LauncherType::Neovide)) {
        app.args.insert(0, "--".to_string());
    }

    match plugin_config.socket_type {
        Some(SocketType::Fsock) => run_fsock(&launcher, app, &nvim, &root_dir, file_str, line)?,
        Some(SocketType::Netsock) => run_netsock(&launcher, app, &nvim, &root_dir, file_str, line)?,
        None => {
            if cfg!(target_os = "linux") || cfg!(target_os = "macos") {
                run_fsock(&launcher, app, &nvim, &root_dir, file_str, line)?;
            } else {
                run_netsock(&launcher, app, &nvim, &root_dir, file_str, line)?;
            }
        }
    }

    if let Err(err) = focus_neovim(root_dir) {
        tracing::error!("Could not switch focus to neovim {err:?}");
    }

    Ok(())
}
