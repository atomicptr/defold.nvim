use anyhow::{Context, Result, bail};
use edn_rs::Edn;
use serde::Deserialize;
use std::{
    fs,
    path::{Path, PathBuf},
    str::FromStr,
};

use crate::bridge;

#[derive(Debug, Deserialize)]
pub enum LauncherType {
    #[serde(rename = "neovide")]
    Neovide,

    #[serde(rename = "terminal")]
    Terminal,
}

#[derive(Debug, Deserialize)]
pub enum SocketType {
    #[serde(rename = "fsock")]
    Fsock,

    #[serde(rename = "netsock")]
    Netsock,
}

#[derive(Debug, Deserialize)]
pub struct TerminalLauncherSettings {
    pub class_argument: Option<String>,
    pub run_argument: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LauncherSettings {
    #[serde(rename = "type")]
    pub launcher_type: LauncherType,
    pub executable: Option<String>,
    pub socket_type: Option<SocketType>,
    pub extra_arguments: Option<Vec<String>>,
    pub terminal: Option<TerminalLauncherSettings>,
    pub debug: Option<bool>,
}

impl LauncherSettings {
    #[must_use]
    pub fn bridge_cli_args(&self) -> Vec<String> {
        let mut args = Vec::new();

        args.push("--launcher-type".to_string());
        args.push(match self.launcher_type {
            LauncherType::Neovide => "neovide".to_string(),
            LauncherType::Terminal => "terminal".to_string(),
        });

        if let Some(socket_type) = &self.socket_type {
            args.push("--socket-type".to_string());
            args.push(match socket_type {
                SocketType::Fsock => "fsock".to_string(),
                SocketType::Netsock => "netsock".to_string(),
            });
        }

        if let Some(executable) = &self.executable {
            args.push("--executable".to_string());
            args.push(executable.clone());
        }

        if let Some(extra_args) = &self.extra_arguments {
            args.push("--extra-arguments".to_string());
            for arg in extra_args {
                args.push(arg.clone());
            }
        }

        if let Some(terminal) = &self.terminal {
            if let Some(class_arg) = &terminal.class_argument {
                args.push("--terminal-class-argument".to_string());
                args.push(class_arg.clone());
            }

            if let Some(run_arg) = &terminal.run_argument {
                args.push("--terminal-run-argument".to_string());
                args.push(run_arg.clone());
            }
        }

        args
    }
}

#[cfg(target_os = "linux")]
const RUN_SCRIPT: &str = include_str!("../assets/run_linux.sh");

#[cfg(target_os = "macos")]
const RUN_SCRIPT: &'static str = include_str!("../assets/run_macos.sh");

#[cfg(target_os = "windows")]
const RUN_SCRIPT: &'static str = include_str!("../assets/run_windows.bat");

#[cfg(target_os = "windows")]
const SCRIPT_EXT: &'static str = "bat";

#[cfg(not(target_os = "windows"))]
const SCRIPT_EXT: &str = "sh";

fn create_runner_script(
    plugin_root: &Path,
    launcher_settings: &LauncherSettings,
) -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim")
        .join("bin");
    fs::create_dir_all(&dir)?;

    let script_path = dir.join(format!("run.{SCRIPT_EXT}"));
    let bridge_path = bridge::path(plugin_root)?;
    let launch_args = launcher_settings.bridge_cli_args().join(" ");

    fs::write(
        &script_path,
        RUN_SCRIPT
            .replace(
                "{BRIDGE_PATH}",
                bridge_path
                    .to_str()
                    .context("could not convert bridge path")?,
            )
            .replace("{LAUNCH_ARGS}", &launch_args)
            .replace(
                "{DEBUG_FLAG}",
                if let Some(debug) = launcher_settings.debug
                    && debug
                {
                    "--debug"
                } else {
                    ""
                },
            ),
    )?;

    #[cfg(not(target_os = "windows"))]
    fs::set_permissions(
        &script_path,
        <fs::Permissions as std::os::unix::fs::PermissionsExt>::from_mode(0o700),
    )?;

    Ok(script_path)
}

pub fn set_default_editor(plugin_root: &Path, launcher_settings: &LauncherSettings) -> Result<()> {
    if !plugin_root.exists() {
        bail!("plugin root '{}' could not be found", plugin_root.display());
    }

    let config_dir = dirs::config_dir().context("could not find config dir")?;
    let path = config_dir.join("Defold").join("prefs.editor_settings");

    if !path.exists() {
        bail!(
            "prefs.editor_settings file {} could not be found",
            path.display()
        );
    }

    let data = fs::read_to_string(&path)?;

    let mut config = Edn::from_str(&data).map_err(|err| anyhow::anyhow!(err.to_string()))?;

    config[":code"][":custom-editor"] = Edn::Str(
        create_runner_script(plugin_root, launcher_settings)?
            .to_str()
            .context("could not convert path to string")?
            .to_string(),
    );
    config[":code"][":open-file"] = Edn::Str("{file}".to_string());
    config[":code"][":open-file-at-line"] = Edn::Str("{file} {line}".to_string());

    let config_str = &Edn::to_string(&config);

    fs::write(path, config_str)?;

    Ok(())
}
