use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
    str::FromStr,
};

use crate::{editor, nvim_server::SocketType, path};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LauncherType {
    Neovide,
    Terminal,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
pub struct LauncherSettings {
    #[serde(rename = "type")]
    pub launcher_type: Option<LauncherType>,
    pub executable: Option<String>,
    pub socket_type: Option<SocketType>,
    pub run_arg: Option<String>,
    pub arguments: Option<Vec<String>>,
    pub appname: Option<String>,
    pub debug: Option<bool>,
}

impl FromStr for LauncherType {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "neovide" => Ok(Self::Neovide),
            "terminal" => Ok(Self::Terminal),
            _ => Err(format!(
                "Invalid launcher type '{value}', expected 'neovide' or 'terminal'"
            )),
        }
    }
}

impl LauncherSettings {
    #[must_use]
    pub fn bridge_pre_cli_args(&self) -> Vec<String> {
        let launcher_type = match self.launcher_type {
            Some(LauncherType::Neovide) | None => "neovide",
            Some(LauncherType::Terminal) => "terminal",
        };

        let mut args = vec!["--launcher-type".to_string(), launcher_type.to_string()];

        if let Some(socket_type) = self.socket_type {
            args.push("--socket-type".to_string());
            args.push(
                match socket_type {
                    SocketType::Fsock => "fsock",
                    SocketType::Netsock => "netsock",
                }
                .to_string(),
            );
        }

        for (flag, value) in [
            ("--executable", &self.executable),
            ("--appname", &self.appname),
            ("--run-arg", &self.run_arg),
        ] {
            if let Some(value) = value {
                args.push(flag.to_string());
                args.push(value.clone());
            }
        }

        args
    }

    #[must_use]
    pub fn bridge_post_cli_args(&self) -> Vec<String> {
        match &self.arguments {
            Some(arguments) => std::iter::once("--".to_string())
                .chain(arguments.iter().cloned())
                .collect(),
            None => Vec::new(),
        }
    }
}

#[cfg(target_os = "windows")]
const RUN_SCRIPT: &str = include_str!("../assets/run_windows.bat");

#[cfg(target_os = "macos")]
const RUN_SCRIPT: &str = include_str!("../assets/run_macos.sh");

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
const RUN_SCRIPT: &str = include_str!("../assets/run_linux.sh");

#[allow(clippy::unnecessary_wraps)]
fn quote_posix(value: &str) -> Result<String> {
    Ok(format!("'{}'", value.replace('\'', r"'\''")))
}

/// cmd.exe can't escape `"` inside quotes, so such values are rejected.
/// Trailing backslashes are doubled, otherwise `\"` would be read as a literal quote.
fn quote_batch(value: &str) -> Result<String> {
    if value.contains(['"', '\n', '\r']) {
        bail!("Launcher arguments can't contain quotes or newlines on Windows: {value}");
    }

    let trailing = value.len() - value.trim_end_matches('\\').len();

    Ok(format!(
        "\"{}{}\"",
        value.replace('%', "%%"),
        "\\".repeat(trailing)
    ))
}

fn quote_all(args: &[String], quote: fn(&str) -> Result<String>) -> Result<String> {
    Ok(args
        .iter()
        .map(|arg| quote(arg))
        .collect::<Result<Vec<_>>>()?
        .join(" "))
}

fn render_runner_script(
    template: &str,
    quote: fn(&str) -> Result<String>,
    bridge_path: &str,
    settings: &LauncherSettings,
) -> Result<String> {
    Ok(template
        .replace("{BRIDGE_PATH}", &quote(bridge_path)?)
        .replace(
            "{DEBUG_FLAG}",
            if settings.debug == Some(true) {
                "--debug"
            } else {
                ""
            },
        )
        .replace(
            "{LAUNCH_PRE_ARGS}",
            &quote_all(&settings.bridge_pre_cli_args(), quote)?,
        )
        .replace(
            "{LAUNCH_POST_ARGS}",
            &quote_all(&settings.bridge_post_cli_args(), quote)?,
        ))
}

fn create_runner(bridge_path: &Path, settings: &LauncherSettings) -> Result<PathBuf> {
    let dir = path::data_dir()?.join("bin");
    fs::create_dir_all(&dir)?;

    let (quote, script_name): (fn(&str) -> Result<String>, _) = if cfg!(target_os = "windows") {
        (quote_batch, "run.bat")
    } else {
        (quote_posix, "run.sh")
    };

    let script_path = dir.join(script_name);

    fs::write(
        &script_path,
        render_runner_script(
            RUN_SCRIPT,
            quote,
            bridge_path
                .to_str()
                .context("could not convert bridge path")?,
            settings,
        )?,
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
    bridge_path: &Path,
    settings: &LauncherSettings,
) -> Result<()> {
    if !editor::is_editor_port(port) {
        bail!("No editor was found running at {port}");
    }

    if !bridge_path.is_file() {
        bail!(
            "bridge executable '{}' could not be found",
            bridge_path.display()
        );
    }

    let config = EditorConfig {
        custom_editor: create_runner(bridge_path, settings)?
            .to_str()
            .context("could not convert path to string")?
            .to_string(),
        open_file: "{file}".to_string(),
        open_file_at_line: "{file} {line}".to_string(),
    };

    editor::client(editor::REQUEST_TIMEOUT)?
        .post(format!("{}/prefs/code", editor::editor_url(port)))
        .json(&config)
        .send()?
        .error_for_status()
        .context("Defold rejected the editor preferences")?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_to_neovide_without_optional_flags() {
        let settings = LauncherSettings::default();

        assert_eq!(
            settings.bridge_pre_cli_args(),
            ["--launcher-type", "neovide"]
        );
        assert_eq!(settings.bridge_post_cli_args(), Vec::<String>::new());
    }

    #[test]
    fn maps_launcher_settings_to_bridge_flags() {
        let settings = LauncherSettings {
            launcher_type: Some(LauncherType::Terminal),
            socket_type: Some(SocketType::Fsock),
            executable: Some("custom launcher".into()),
            appname: Some("my nvim".into()),
            run_arg: Some("--execute".into()),
            arguments: Some(vec!["--socket-type".into(), String::new()]),
            ..Default::default()
        };

        assert_eq!(
            settings.bridge_pre_cli_args(),
            [
                "--launcher-type",
                "terminal",
                "--socket-type",
                "fsock",
                "--executable",
                "custom launcher",
                "--appname",
                "my nvim",
                "--run-arg",
                "--execute",
            ]
        );
        assert_eq!(settings.bridge_post_cli_args(), ["--", "--socket-type", ""]);
    }

    #[test]
    fn posix_quoting_keeps_values_literal() {
        assert_eq!(quote_posix("/a b/c").unwrap(), "'/a b/c'");
        assert_eq!(
            quote_posix("it's $HOME `x`").unwrap(),
            r"'it'\''s $HOME `x`'"
        );
        assert_eq!(quote_posix("").unwrap(), "''");
    }

    #[test]
    fn batch_quoting_escapes_percent_and_trailing_backslashes() {
        assert_eq!(
            quote_batch(r"C:\Program Files\100%\bridge.exe").unwrap(),
            r#""C:\Program Files\100%%\bridge.exe""#
        );
        assert_eq!(quote_batch(r"C:\My Dir\").unwrap(), r#""C:\My Dir\\""#);
        assert_eq!(quote_batch("a & b | c").unwrap(), r#""a & b | c""#);
        assert_eq!(quote_batch("").unwrap(), r#""""#);
        assert!(quote_batch(r#"--title="x""#).is_err());
        assert!(quote_batch("a\nb").is_err());
    }

    #[test]
    fn renders_runner_scripts_without_splitting_arguments() {
        let settings = LauncherSettings {
            executable: Some("/My Apps/neovide".into()),
            arguments: Some(vec!["a b".into(), String::new()]),
            debug: Some(true),
            ..Default::default()
        };

        let script = render_runner_script(
            include_str!("../assets/run_linux.sh"),
            quote_posix,
            "/my dir/bridge",
            &settings,
        )
        .unwrap();

        assert_eq!(
            script.lines().nth(1).unwrap(),
            r#"'/my dir/bridge' --debug launch-neovim --show-error-dialog '--launcher-type' 'neovide' '--executable' '/My Apps/neovide' "$(realpath .)" "$1" $2 '--' 'a b' ''"#
        );

        let script = render_runner_script(
            include_str!("../assets/run_windows.bat"),
            quote_batch,
            r"C:\a b\bridge.exe",
            &LauncherSettings::default(),
        )
        .unwrap();

        assert_eq!(
            script.lines().nth(1).unwrap(),
            r#""C:\a b\bridge.exe"  launch-neovim --show-error-dialog "--launcher-type" "neovide" "%CD%" "%~1" %2 "#
        );
    }
}
