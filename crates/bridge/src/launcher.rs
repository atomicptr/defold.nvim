use std::{
    fs::{self},
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{Context, Result, bail};
use defold_nvim_core::{focus::focus_neovim, utils::classname};
use which::which;

use crate::{
    neovide,
    plugin_config::{LauncherType, PluginConfig, SocketType},
    terminals::{RunArg, Terminal},
    utils::{self, is_port_in_use},
};

const ERR_NEOVIDE_NOT_FOUND: &str = "Could not find Neovide, have you installed it?";
const ERR_TERMINAL_NOT_FOUND: &str = "Could not find any suitable terminal";

const VAR_CLASSNAME: &str = "{CLASSNAME}";
const VAR_ADDRESS: &str = "{ADDR}";
const VAR_LINE: &str = "{LINE}";
const VAR_FILE: &str = "{FILE}";
const VAR_NVIM: &str = "{NVIM}";

#[derive(Debug)]
struct Launcher(PathBuf, Vec<String>);

impl Launcher {
    fn run(self) -> Result<()> {
        tracing::debug!("Run launcher {self:?}");

        let exe = self.0;
        let args = self.1;

        let mut cmd = Command::new(exe);
        cmd.args(args);

        tracing::debug!("Command Run: {cmd:?}");

        let out = cmd.output()?;

        if !out.stdout.is_empty() {
            tracing::debug!("Command Out: {}", String::from_utf8(out.stdout)?);
        }

        if !out.stderr.is_empty() {
            let res = String::from_utf8(out.stderr)?;
            tracing::error!("Command Err: {res}");
            bail!(res);
        }

        Ok(())
    }

    fn apply_var(self, var: &str, replace_with: &str) -> Self {
        Self(
            self.0,
            self.1
                .iter()
                .map(|s| s.replace(var, replace_with))
                .collect(),
        )
    }

    fn filter_params<F>(self, f: F) -> Self
    where
        F: Fn(&String) -> bool,
    {
        Self(self.0, self.1.into_iter().filter(|s| f(s)).collect())
    }
}

fn create_launcher(cfg: &PluginConfig, nvim: &String) -> Result<Launcher> {
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

            let mut args = Vec::new();

            if let Some(exe_args) = &cfg.arguments {
                for exe_arg in exe_args {
                    args.push(exe_arg.clone());
                }
            }

            args.push("--neovim-bin".to_string());
            args.push(nvim.clone());

            // only add class on linux
            if cfg!(target_os = "linux") {
                args.push("--wayland_app_id".to_string());
                args.push(VAR_CLASSNAME.to_string());

                args.push("--x11-wm-class".to_string());
                args.push(VAR_CLASSNAME.to_string());
            }

            args.push("--".to_string());

            args.push("--listen".to_string());
            args.push(VAR_ADDRESS.to_string());

            args.push("--remote".to_string());
            args.push(VAR_LINE.to_string());
            args.push(VAR_FILE.to_string());

            Ok(Launcher(executable.clone(), args))
        }
        Some(LauncherType::Terminal) => {
            let mut args = Vec::new();

            if let Some(exe_args) = &cfg.arguments {
                for exe_arg in exe_args {
                    args.push(exe_arg.clone());
                }
            }

            if let Some(executable) = &cfg.executable.clone().map(PathBuf::from)
                && executable.is_absolute()
                && executable.exists()
            {
                let term = Terminal {
                    executable: cfg.executable.clone().unwrap(),
                    arguments: Vec::new(),
                    run_arg: None,
                    class_arg: None,
                };

                tracing::debug!("Terminal specified by absolute path {term:?}");

                return make_launcher_from_terminal(&term, args, nvim)
                    .context(ERR_TERMINAL_NOT_FOUND);
            } else if let Some(exe_name) = &cfg.executable
                && let Some(term) = Terminal::find_by_name(exe_name)
                && term.find_executable().is_some()
            {
                tracing::debug!("Looking for terminal by name {exe_name} found {term:?}");

                // executable specifies only the name o f which terminal we want to use
                return make_launcher_from_terminal(&term, args, nvim)
                    .context(ERR_TERMINAL_NOT_FOUND);
            }

            tracing::debug!(
                "No terminal specific terminal specified or not found, looking for available one..."
            );

            if let Some(term) = Terminal::find_available() {
                tracing::debug!("Found {term:?}");

                return make_launcher_from_terminal(&term, args, nvim)
                    .context(ERR_TERMINAL_NOT_FOUND);
            }

            bail!(ERR_TERMINAL_NOT_FOUND);
        }
        None => {
            if let Ok(launcher) = create_launcher(
                &PluginConfig {
                    launcher_type: Some(LauncherType::Neovide),
                    ..cfg.clone()
                },
                nvim,
            ) {
                return Ok(launcher);
            }

            if let Ok(launcher) = create_launcher(
                &PluginConfig {
                    launcher_type: Some(LauncherType::Terminal),
                    ..cfg.clone()
                },
                nvim,
            ) {
                return Ok(launcher);
            }

            bail!("Could neither find Neovide nor any supported terminal")
        }
    }
}

fn make_launcher_from_terminal(
    term: &Terminal,
    mut args: Vec<String>,
    nvim: &String,
) -> Option<Launcher> {
    let exe_path = term.find_executable()?;

    // prepend our arguments
    for arg in term.arguments.iter().rev() {
        args.insert(0, arg.clone());
    }

    // only add class on linux
    if cfg!(target_os = "linux")
        && let Some(class_arg) = &term.class_arg
    {
        if class_arg.ends_with('=') {
            args.push((*class_arg).clone() + VAR_CLASSNAME);
        } else {
            args.push((*class_arg).clone());
            args.push(VAR_CLASSNAME.to_string());
        }
    }

    if let Some(run_arg) = &term.run_arg {
        match run_arg {
            RunArg::Arg(run_arg) => {
                if run_arg.ends_with('=') {
                    args.push((*run_arg).clone() + nvim);
                } else {
                    args.push((*run_arg).clone());
                    args.push((*nvim).clone());
                }
            }
            RunArg::End => {
                args.push("--".to_string());
                args.push(nvim.clone());
            }
        }
    }

    args.push("--listen".to_string());
    args.push(VAR_ADDRESS.to_string());

    args.push("--remote".to_string());
    args.push(VAR_LINE.to_string());
    args.push(VAR_FILE.to_string());

    Some(Launcher(exe_path, args))
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
    launcher: Launcher,
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

    let launcher = launcher.apply_var(
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
            launcher.run()?;
        }

        return Ok(());
    }

    launcher.run()?;
    Ok(())
}

fn run_netsock(
    launcher: Launcher,
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
            launcher.apply_var(VAR_ADDRESS, &socket).run()?;
        }

        return Ok(());
    }

    fs::write(port_file, port.to_string())?;
    launcher.apply_var(VAR_ADDRESS, &socket).run()?;
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

    let launcher = create_launcher(plugin_config, &nvim)?;

    let launcher = if cfg!(target_os = "linux") {
        launcher.apply_var(
            VAR_CLASSNAME,
            &classname(
                root_dir
                    .to_str()
                    .context("could not convert path to string")?,
            )?,
        )
    } else {
        launcher
    };

    let file_str = file.to_str().context("could not convert path to string")?;

    let launcher = if let Some(line) = line {
        launcher.apply_var(VAR_LINE, &format!("+{line}"))
    } else {
        launcher.filter_params(|s| s != VAR_LINE)
    };

    let launcher = launcher
        .apply_var(VAR_FILE, file_str)
        .apply_var(VAR_NVIM, &nvim);

    match plugin_config.socket_type {
        Some(SocketType::Fsock) => run_fsock(launcher, &nvim, &root_dir, file_str, line)?,
        Some(SocketType::Netsock) => run_netsock(launcher, &nvim, &root_dir, file_str, line)?,
        None => {
            if cfg!(target_os = "linux") || cfg!(target_os = "macos") {
                run_fsock(launcher, &nvim, &root_dir, file_str, line)?;
            } else {
                run_netsock(launcher, &nvim, &root_dir, file_str, line)?;
            }
        }
    }

    if let Err(err) = focus_neovim(root_dir) {
        tracing::error!("Could not switch focus to neovim {err:?}");
    }

    Ok(())
}
