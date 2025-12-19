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
    utils::{self, is_port_in_use},
};

const ERR_NEOVIDE_NOT_FOUND: &str = "Could not find Neovide, have you installed it?";
const ERR_TERMINAL_NOT_FOUND: &str = "Could not find any suitable terminal";

const VAR_CLASSNAME: &str = "{CLASSNAME}";
const VAR_ADDRESS: &str = "{ADDR}";
const VAR_REMOTE_CMD: &str = "{REMOTE_CMD}";

#[derive(Debug)]
struct Launcher(PathBuf, Vec<String>);

impl Launcher {
    fn run(self) -> Result<()> {
        tracing::debug!("Run launcher {self:?}");

        let exe = self.0;
        let args = self.1;

        let out = Command::new(exe).args(args).output()?;

        if !out.stderr.is_empty() {
            bail!(String::from_utf8(out.stderr)?);
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
}

const DEFAULT_TERMINALS: [(&str, &str, &str); 5] = [
    ("alacratty", "--class=", "-e"),
    ("foot", "--app-id=", "-e"),
    ("ghostty", "--class=", "-e"),
    ("kitty", "--class=", "-e"),
    ("st", "-c=", "-e"),
];

fn create_launcher(cfg: &PluginConfig, nvim: &String) -> Result<Launcher> {
    match cfg.launcher_type {
        Some(LauncherType::Neovide) => {
            let executable = &cfg
                .executable
                .as_ref()
                .map(Into::into)
                .or_else(|| which("neovide").ok())
                .or_else(|| match neovide::update_or_install() {
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

            if let Some(extra_args) = &cfg.extra_arguments {
                for extra_arg in extra_args {
                    args.push(extra_arg.clone());
                }
            }

            args.push("--neovim-bin".to_string());
            args.push(nvim.clone());

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
            args.push(VAR_REMOTE_CMD.to_string());

            Ok(Launcher(executable.clone(), args))
        }
        Some(LauncherType::Terminal) => {
            let executable: Option<PathBuf> = cfg.executable.clone().map(Into::into);

            let executable = if let Some(exe) = executable
                && exe.exists()
            {
                let class_arg = &cfg.terminal_class_argument;
                let run_arg = &cfg.terminal_run_argument;
                let mut args = Vec::new();

                if let Some(extra_args) = &cfg.extra_arguments {
                    for extra_arg in extra_args {
                        args.push(extra_arg.clone());
                    }
                }

                if let Some(class_arg) = class_arg {
                    if class_arg.ends_with('=') {
                        args.push(class_arg.clone() + VAR_CLASSNAME);
                    } else {
                        args.push(class_arg.clone());
                        args.push(VAR_CLASSNAME.to_string());
                    }
                }

                if let Some(run_arg) = run_arg {
                    if run_arg.ends_with('=') {
                        args.push(run_arg.clone() + nvim);
                    } else {
                        args.push(run_arg.clone());
                        args.push(nvim.clone());
                    }
                }

                args.push("--listen".to_string());
                args.push(VAR_ADDRESS.to_string());

                args.push("--remote".to_string());
                args.push(VAR_REMOTE_CMD.to_string());

                Some(Launcher(exe, args))
            } else {
                None
            }
            .or_else(|| {
                let mut args = Vec::new();

                if let Some(extra_args) = &cfg.extra_arguments {
                    for extra_arg in extra_args {
                        args.push(extra_arg.clone());
                    }
                }

                // executable specifies only the name of which terminal we want to use
                if let Some(exe_name) = &cfg.executable
                    && let Some((name, class_arg, run_arg)) = DEFAULT_TERMINALS
                        .iter()
                        .find(|(name, _, _)| *name == exe_name)
                    && let Ok(path) = which(name)
                {
                    if class_arg.ends_with('=') {
                        args.push((*class_arg).to_string() + VAR_CLASSNAME);
                    } else {
                        args.push((*class_arg).to_string());
                        args.push(VAR_CLASSNAME.to_string());
                    }

                    if run_arg.ends_with('=') {
                        args.push((*run_arg).to_string() + nvim);
                    } else {
                        args.push((*run_arg).to_string());
                        args.push((*nvim).clone());
                    }

                    args.push("--listen".to_string());
                    args.push(VAR_ADDRESS.to_string());

                    args.push("--remote".to_string());
                    args.push(VAR_REMOTE_CMD.to_string());

                    return Some(Launcher(path, args));
                }

                // try finding one of our supported default terminals
                for (name, class_arg, run_arg) in &DEFAULT_TERMINALS {
                    if let Ok(path) = which(name) {
                        if class_arg.ends_with('=') {
                            args.push((*class_arg).to_string() + VAR_CLASSNAME);
                        } else {
                            args.push((*class_arg).to_string());
                            args.push(VAR_CLASSNAME.to_string());
                        }

                        if run_arg.ends_with('=') {
                            args.push((*run_arg).to_string() + nvim);
                        } else {
                            args.push((*run_arg).to_string());
                            args.push((*nvim).clone());
                        }

                        args.push("--listen".to_string());
                        args.push(VAR_ADDRESS.to_string());

                        args.push("--remote".to_string());
                        args.push(VAR_REMOTE_CMD.to_string());

                        return Some(Launcher(path, args));
                    }
                }
                None
            })
            .context(ERR_TERMINAL_NOT_FOUND)?;

            Ok(executable)
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

fn nvim_open_file_remote(nvim: &str, server: &str, remote_cmd: &str) -> Result<()> {
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

fn run_fsock(launcher: Launcher, nvim: &str, root_dir: &Path, remote_cmd: &str) -> Result<()> {
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
            remote_cmd,
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

fn run_netsock(launcher: Launcher, nvim: &str, root_dir: &Path, remote_cmd: &str) -> Result<()> {
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
        if let Err(err) = nvim_open_file_remote(nvim, &socket, remote_cmd) {
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
    plugin_config: PluginConfig,
    root_dir: PathBuf,
    file: &Path,
    line: Option<usize>,
) -> Result<()> {
    let nvim = which("nvim")?
        .to_str()
        .context("could not convert nvim path to string")?
        .to_string();

    let launcher = create_launcher(&plugin_config, &nvim)?;

    let launcher = if cfg!(target_os = "linux") {
        launcher.apply_var(
            VAR_CLASSNAME,
            &classname(
                root_dir
                    .to_str()
                    .context("could not convert path to string")?,
            )?,
        )
    } else if cfg!(target_os = "macos") {
        // TODO: macos
        launcher
    } else if cfg!(target_os = "windows") {
        // TODO: windows
        launcher
    } else {
        launcher
    };

    let file_str = file.to_str().context("could not convert path to string")?;

    let remote_cmd = match line {
        Some(line) => format!("+{line} {file_str}"),
        None => file_str.to_string(),
    };

    let launcher = launcher.apply_var(VAR_REMOTE_CMD, &remote_cmd.clone());

    match plugin_config.socket_type {
        Some(SocketType::Fsock) => run_fsock(launcher, &nvim, &root_dir, &remote_cmd)?,
        Some(SocketType::Netsock) => run_netsock(launcher, &nvim, &root_dir, &remote_cmd)?,
        None => {
            if cfg!(target_os = "linux") || cfg!(target_os = "macos") {
                run_fsock(launcher, &nvim, &root_dir, &remote_cmd)?;
            } else {
                run_netsock(launcher, &nvim, &root_dir, &remote_cmd)?;
            }
        }
    }

    if let Err(err) = focus_neovim(root_dir) {
        tracing::error!("Could not switch focus to neovim {err:?}");
    }

    Ok(())
}
