use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    fmt::Write as _,
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
    #[serde(default, deserialize_with = "deserialize_env")]
    pub env: BTreeMap<String, String>,
    pub debug: Option<bool>,
}

// custom deserializer for our custom env lua table nonsense
fn deserialize_env<'de, D>(deserializer: D) -> Result<BTreeMap<String, String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    #[derive(Deserialize)]
    #[serde(untagged)]
    enum EnvScalar {
        String(String),
        Boolean(bool),
        Number(serde_json::Number),
    }

    impl EnvScalar {
        fn into_string(self) -> String {
            match self {
                Self::String(value) => value,
                Self::Boolean(value) => if value { "1" } else { "0" }.to_string(),
                Self::Number(value) => value.to_string(),
            }
        }
    }

    #[derive(Deserialize, PartialEq, Eq, PartialOrd, Ord)]
    #[serde(untagged)]
    enum EnvKey {
        Index(std::num::NonZeroUsize),
        Name(String),
    }

    #[derive(Deserialize)]
    #[serde(untagged)]
    enum EnvValue {
        Scalar(EnvScalar),
        List(Vec<EnvScalar>),
        Map(BTreeMap<EnvKey, EnvScalar>),
    }

    let env = BTreeMap::<String, EnvValue>::deserialize(deserializer)?;

    Ok(env
        .into_iter()
        .map(|(name, value)| {
            let value = match value {
                EnvValue::Scalar(value) => value.into_string(),
                EnvValue::List(values) => values
                    .into_iter()
                    .map(EnvScalar::into_string)
                    .collect::<Vec<_>>()
                    .join(","),
                EnvValue::Map(values) => values
                    .into_iter()
                    .map(|(key, value)| match key {
                        EnvKey::Index(_) => value.into_string(),
                        EnvKey::Name(key) => format!("{key}={}", value.into_string()),
                    })
                    .collect::<Vec<_>>()
                    .join(","),
            };

            (name, value)
        })
        .collect())
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

fn render_env(env: &BTreeMap<String, String>, batch: bool) -> Result<String> {
    let mut exports = String::new();

    for (name, value) in env {
        let mut chars = name.chars();
        let valid = chars
            .next()
            .is_some_and(|c| c.is_ascii_alphabetic() || c == '_')
            && chars.all(|c| c.is_ascii_alphanumeric() || c == '_');

        if !valid {
            bail!("Invalid launcher.env variable name: {name:?}");
        }

        if value.contains('\0') {
            bail!("launcher.env value for {name} cannot contain NUL bytes");
        }

        if batch {
            if value.contains(['"', '\n', '\r']) {
                bail!("launcher.env value for {name} cannot contain quotes or newlines on Windows");
            }

            writeln!(exports, "set \"{name}={}\"", value.replace('%', "%%"))?;
        } else {
            writeln!(exports, "export {name}={}", quote_posix(value)?)?;
        }
    }

    if batch && !exports.is_empty() {
        // cmd.exe otherwise decodes UTF-8 values using the active legacy code page.
        exports.insert_str(0, "setlocal DisableDelayedExpansion\nchcp 65001 >nul\n");
    }

    Ok(exports)
}

fn render_runner_script(
    template: &str,
    quote: fn(&str) -> Result<String>,
    bridge_path: &str,
    settings: &LauncherSettings,
) -> Result<String> {
    let batch = template.contains("{ENV_BATCH}");
    let exports = render_env(&settings.env, batch)?;

    let (header, command) = template
        .split_once(if batch { "{ENV_BATCH}" } else { "{ENV}" })
        .context("Runner template is missing its environment placeholder")?;

    let command = command
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
        );

    Ok(format!("{header}{exports}{command}"))
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

    fn with_env(entries: &[(&str, &str)]) -> LauncherSettings {
        LauncherSettings {
            env: entries
                .iter()
                .map(|(name, value)| ((*name).into(), (*value).into()))
                .collect(),
            ..Default::default()
        }
    }

    #[test]
    fn deserializes_environment_settings() {
        for json in [r#"{}"#, r#"{"env":{}}"#] {
            let settings: LauncherSettings = serde_json::from_str(json).unwrap();
            assert_eq!(render_env(&settings.env, false).unwrap(), "");
        }

        let settings: LauncherSettings =
            serde_json::from_str(r#"{"env":{"SOMETHING":"yolo","EMPTY":""}}"#).unwrap();
        assert_eq!(
            render_env(&settings.env, false).unwrap(),
            "export EMPTY=''\nexport SOMETHING='yolo'\n"
        );

        for json in [
            r#"{"env":[]}"#,
            r#"{"env":{"X":null}}"#,
            r#"{"env":{"X":[[]]}}"#,
            r#"{"env":{"X":[null]}}"#,
            r#"{"env":{"X":[{}]}}"#,
            r#"{"env":{"X":{"key":[]}}}"#,
            r#"{"env":{"X":{"key":{}}}}"#,
        ] {
            assert!(serde_json::from_str::<LauncherSettings>(json).is_err());
        }
    }

    #[test]
    fn normalizes_boolean_environment_values() {
        let settings: LauncherSettings =
            serde_json::from_str(r#"{"env":{"ENABLED":true,"DISABLED":false,"TEXT":"false"}}"#)
                .unwrap();
        assert_eq!(settings.env["ENABLED"], "1");
        assert_eq!(settings.env["DISABLED"], "0");
        assert_eq!(settings.env["TEXT"], "false");
        assert_eq!(
            render_env(&settings.env, false).unwrap(),
            "export DISABLED='0'\nexport ENABLED='1'\nexport TEXT='false'\n"
        );
        assert_eq!(
            render_env(&settings.env, true).unwrap(),
            "setlocal DisableDelayedExpansion\nchcp 65001 >nul\nset \"DISABLED=0\"\nset \"ENABLED=1\"\nset \"TEXT=false\"\n"
        );
    }

    #[test]
    fn normalizes_numbers_and_flat_lists() {
        let settings: LauncherSettings = serde_json::from_str(
            r#"{"env":{"PORT":8080,"NEGATIVE":-42,"FRACTION":1.25,"EMPTY":[],"ITEMS":["a,b",42,true,false,""],"TEXT":"001"}}"#,
        ).unwrap();
        assert_eq!(settings.env["PORT"], "8080");
        assert_eq!(settings.env["NEGATIVE"], "-42");
        assert_eq!(settings.env["FRACTION"], "1.25");
        assert_eq!(settings.env["EMPTY"], "");
        assert_eq!(settings.env["ITEMS"], "a,b,42,1,0,");
        assert_eq!(settings.env["TEXT"], "001");
        let posix = render_env(&settings.env, false).unwrap();
        let batch = render_env(&settings.env, true).unwrap();
        assert!(posix.contains("export ITEMS='a,b,42,1,0,'\n"));
        assert!(batch.contains("set \"ITEMS=a,b,42,1,0,\"\n"));
    }

    #[test]
    fn normalizes_sorted_key_value_maps() {
        let settings: LauncherSettings = serde_json::from_str(
            r#"{"env":{"VALUE":{"b":2,"a":1,"flag":false,"text":"a=b"},"EMPTY":{}}}"#,
        )
        .unwrap();
        assert_eq!(settings.env["VALUE"], "a=1,b=2,flag=0,text=a=b");
        assert_eq!(settings.env["EMPTY"], "");
        assert!(
            render_env(&settings.env, false)
                .unwrap()
                .contains("export VALUE='a=1,b=2,flag=0,text=a=b'\n")
        );
        assert!(
            render_env(&settings.env, true)
                .unwrap()
                .contains("set \"VALUE=a=1,b=2,flag=0,text=a=b\"\n")
        );
    }

    #[test]
    fn normalizes_mixed_tables_with_list_items_before_sorted_names() {
        let settings: LauncherSettings = serde_yaml::from_str(
            "env:\n  RUST_LOG:\n    z: false\n    2: warn\n    defold_nvim: debug\n    1: info\n",
        )
        .unwrap();
        assert_eq!(settings.env["RUST_LOG"], "info,warn,defold_nvim=debug,z=0");
        assert!(
            render_env(&settings.env, false)
                .unwrap()
                .contains("export RUST_LOG='info,warn,defold_nvim=debug,z=0'\n")
        );
        assert!(
            render_env(&settings.env, true)
                .unwrap()
                .contains("set \"RUST_LOG=info,warn,defold_nvim=debug,z=0\"\n")
        );

        for key in ["0", "-1", "1.5", "true"] {
            let yaml = format!("env:\n  VALUE:\n    {key}: bad\n    name: valid\n");
            assert!(serde_yaml::from_str::<LauncherSettings>(&yaml).is_err());
        }
    }

    #[test]
    fn rejects_invalid_environment_entries() {
        for name in ["", "1NAME", "A=B", "A B", "A-B", "A\nB", "Ä", "A\0B"] {
            for batch in [false, true] {
                assert!(render_env(&with_env(&[(name, "secret")]).env, batch).is_err());
            }
        }

        let error = render_env(&with_env(&[("VALID", "secret\0value")]).env, false).unwrap_err();
        assert!(!error.to_string().contains("secret"));
        assert_eq!(
            render_env(&with_env(&[("_NAME2", "")]).env, false).unwrap(),
            "export _NAME2=''\n"
        );
    }

    #[test]
    fn renders_literal_environment_after_macos_path_setup() {
        let settings = with_env(&[
            ("Z", "{ENV}{BRIDGE_PATH}{LAUNCH_PRE_ARGS}{LAUNCH_POST_ARGS}"),
            ("PATH", "/custom/bin"),
        ]);
        let script = render_runner_script(
            include_str!("../assets/run_macos.sh"),
            quote_posix,
            "/bridge",
            &settings,
        )
        .unwrap();
        let lines: Vec<_> = script.lines().collect();
        assert!(lines[1].starts_with("export PATH=\"/opt/homebrew/bin:"));
        assert_eq!(lines[2], "export PATH='/custom/bin'");
        assert_eq!(
            lines[3],
            "export Z='{ENV}{BRIDGE_PATH}{LAUNCH_PRE_ARGS}{LAUNCH_POST_ARGS}'"
        );
        assert!(lines[4].starts_with("'/bridge'"));
    }

    #[test]
    fn renders_batch_environment_safely() {
        let template = include_str!("../assets/run_windows.bat");
        let settings = with_env(&[
            ("VALUE", "100% %PATH% !x! ^ & | < > ( ) {ENV_BATCH}\\"),
            ("EMPTY", ""),
        ]);
        let script = render_runner_script(template, quote_batch, "bridge.exe", &settings).unwrap();
        assert!(script.starts_with("@echo off\nsetlocal DisableDelayedExpansion\nchcp 65001 >nul\nset \"EMPTY=\"\nset \"VALUE=100%% %%PATH%% !x! ^ & | < > ( ) {ENV_BATCH}\\\"\n\"bridge.exe\""));
        let empty =
            render_runner_script(template, quote_batch, "bridge.exe", &with_env(&[])).unwrap();
        assert!(!empty.contains("setlocal"));

        for value in [
            "secret\"value",
            "secret\nvalue",
            "secret\rvalue",
            "secret\0value",
        ] {
            let error = render_runner_script(
                template,
                quote_batch,
                "bridge.exe",
                &with_env(&[("VALUE", value)]),
            )
            .unwrap_err();
            assert!(!error.to_string().contains("secret"));
        }
    }

    #[cfg(windows)]
    #[test]
    fn batch_runner_preserves_literal_values_and_inherits_environment() {
        let dir = std::env::temp_dir().join(format!("defold env test {}", std::process::id()));
        fs::create_dir(&dir).unwrap();
        let bridge = dir.join("capture.bat");
        let runner = dir.join("run.bat");
        let wrapper = dir.join("legacy.bat");
        fs::write(&bridge, "@set DEFOLD_TEST_\r\n").unwrap();
        let value = "café 日本語 100% %PATH% !x! ^ & | < > ( ) \\";
        let settings = with_env(&[("DEFOLD_TEST_VALUE", value), ("DEFOLD_TEST_EMPTY", "")]);
        let script = render_runner_script(
            include_str!("../assets/run_windows.bat"),
            quote_batch,
            bridge.to_str().unwrap(),
            &settings,
        )
        .unwrap();
        fs::write(&runner, script).unwrap();
        fs::write(&wrapper, "@echo off\nchcp 437 >nul\ncall run.bat\n").unwrap();
        let output = std::process::Command::new("cmd.exe")
            .args(["/D", "/V:ON", "/C"])
            .arg("legacy.bat")
            .current_dir(&dir)
            .env("DEFOLD_TEST_VALUE", "old")
            .env("DEFOLD_TEST_EMPTY", "old")
            .env("DEFOLD_TEST_INHERITED", "inherited")
            .output();
        fs::remove_dir_all(&dir).unwrap();
        let output = output.unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        let stdout = String::from_utf8(output.stdout).unwrap();
        let lines: Vec<_> = stdout.lines().collect();
        assert!(lines.contains(&format!("DEFOLD_TEST_VALUE={value}").as_str()));
        assert!(lines.contains(&"DEFOLD_TEST_INHERITED=inherited"));
        assert!(
            !lines
                .iter()
                .any(|line| line.starts_with("DEFOLD_TEST_EMPTY="))
        );
    }

    #[cfg(unix)]
    #[test]
    fn bash_runner_preserves_literal_values_and_inherits_environment() {
        let value = "it's $HOME `printf BAD` $(printf BAD) \\\n\"quoted\" {ENV}";
        let settings = with_env(&[("DEFOLD_TEST_VALUE", value), ("DEFOLD_TEST_EMPTY", "")]);
        let script = render_runner_script(
            include_str!("../assets/run_linux.sh"),
            quote_posix,
            "capture",
            &settings,
        )
        .unwrap();
        let script = format!(
            "capture() {{ printf '%s\\0' \"$DEFOLD_TEST_VALUE\" \"${{DEFOLD_TEST_EMPTY-unset}}\" \"$DEFOLD_TEST_INHERITED\" \"$@\"; }}\n{script}"
        );
        let output = std::process::Command::new("bash")
            .args(["-c", &script, "runner", "a b.lua", "12"])
            .env("DEFOLD_TEST_VALUE", "old")
            .env("DEFOLD_TEST_INHERITED", "inherited")
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        let values: Vec<_> = output.stdout.split(|b| *b == 0).collect();
        assert_eq!(values[0], value.as_bytes());
        assert_eq!(values[1], b"");
        assert_eq!(values[2], b"inherited");
        assert_eq!(values[values.len() - 3], b"a b.lua");
        assert_eq!(values[values.len() - 2], b"12");
    }

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
