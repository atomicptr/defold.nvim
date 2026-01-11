use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::{bridge, editor};

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
pub struct LauncherSettings {
    #[serde(rename = "type")]
    pub launcher_type: Option<LauncherType>,
    pub executable: Option<String>,
    pub socket_type: Option<SocketType>,
    pub arguments: Option<Vec<String>>,
    pub debug: Option<bool>,
}

impl LauncherSettings {
    #[must_use]
    pub fn bridge_pre_cli_args(&self) -> Vec<String> {
        let mut args = Vec::new();

        args.push("--launcher-type".to_string());
        args.push(match self.launcher_type {
            Some(LauncherType::Neovide) | None => "neovide".to_string(),
            Some(LauncherType::Terminal) => "terminal".to_string(),
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

        args
    }

    #[must_use]
    pub fn bridge_post_cli_args(&self) -> Vec<String> {
        let mut args = Vec::new();

        if let Some(exe_args) = &self.arguments {
            args.push("--".to_string());
            for arg in exe_args {
                args.push(arg.clone());
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
    let bridge_path = bridge::path(Some(plugin_root))?;
    let launch_pre_args = launcher_settings.bridge_pre_cli_args().join(" ");
    let launch_post_args = launcher_settings.bridge_post_cli_args().join(" ");

    fs::write(
        &script_path,
        RUN_SCRIPT
            .replace(
                "{BRIDGE_PATH}",
                bridge_path
                    .to_str()
                    .context("could not convert bridge path")?,
            )
            .replace("{LAUNCH_PRE_ARGS}", &launch_pre_args)
            .replace(
                "{DEBUG_FLAG}",
                if let Some(debug) = launcher_settings.debug
                    && debug
                {
                    "--debug"
                } else {
                    ""
                },
            )
            .replace("{LAUNCH_POST_ARGS}", &launch_post_args),
    )?;

    #[cfg(not(target_os = "windows"))]
    fs::set_permissions(
        &script_path,
        <fs::Permissions as std::os::unix::fs::PermissionsExt>::from_mode(0o700),
    )?;

    Ok(script_path)
}

#[derive(Serialize)]
struct EditorConfig {
    #[serde(rename = "custom-editor")]
    custom_editor: String,

    #[serde(rename = "open-file")]
    open_file: String,

    #[serde(rename = "open-file-at-line")]
    open_file_at_line: String,
}

pub fn set_default_editor(
    port: u16,
    plugin_root: &Path,
    launcher_settings: &LauncherSettings,
) -> Result<()> {
    if !editor::is_editor_port(port) {
        bail!("No edito was found runnign at {port}");
    }

    if !plugin_root.exists() {
        bail!("plugin root '{}' could not be found", plugin_root.display());
    }

    let config = EditorConfig {
        custom_editor: create_runner_script(plugin_root, launcher_settings)?
            .to_str()
            .context("could not convert path to string")?
            .to_string(),
        open_file: "{file}".to_string(),
        open_file_at_line: "{file} {line}".to_string(),
    };

    let url = format!("http://localhost:{port}/prefs/code");

    reqwest::blocking::Client::new()
        .post(url)
        .json(&config)
        .send()?;

    Ok(())
}
