use anyhow::{Context, Result, bail};
use edn_rs::Edn;
use std::{fs, path::PathBuf, str::FromStr};

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

#[cfg(target_os = "windows")]
const EXE_SUFFIX: &'static str = ".exe";

#[cfg(not(target_os = "windows"))]
const EXE_SUFFIX: &str = "";

fn find_bridge_path(plugin_root: PathBuf) -> Result<PathBuf> {
    let exe = format!("defold-nvim-bridge{}", EXE_SUFFIX);

    if plugin_root.exists() {
        let candidates = [
            plugin_root.join(&exe),
            plugin_root.join("target").join("debug").join(&exe),
            plugin_root.join("target").join("release").join(&exe),
        ];

        if let Some(bridge_path) = candidates.into_iter().find(|p| p.exists()) {
            return Ok(bridge_path);
        }
    }

    // TODO: if not lets download it
    panic!("not yet implemented!")
}

fn create_runner_script(plugin_root: PathBuf, launch_config: PathBuf) -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim");
    fs::create_dir_all(&dir)?;

    let script_path = dir.join(format!("run.{SCRIPT_EXT}"));

    let bridge_path = find_bridge_path(plugin_root)?;

    fs::write(
        &script_path,
        RUN_SCRIPT
            .replace(
                "{BRIDGE_PATH}",
                bridge_path
                    .to_str()
                    .context("could not convert bridge path")?,
            )
            .replace(
                "{LAUNCH_CONFIG}",
                launch_config
                    .to_str()
                    .context("could not convert launch config")?,
            ),
    )?;

    #[cfg(not(target_os = "windows"))]
    fs::set_permissions(
        &script_path,
        <fs::Permissions as std::os::unix::fs::PermissionsExt>::from_mode(0o700),
    )?;

    Ok(script_path)
}

pub fn set_default_editor(plugin_root: PathBuf, launch_config: PathBuf) -> Result<()> {
    if !plugin_root.exists() {
        bail!("plugin root '{plugin_root:?}' could not be found");
    }

    if !launch_config.exists() {
        bail!("launch config path '{launch_config:?}' could not be found");
    }

    let config_dir = dirs::config_dir().context("could not find config dir")?;
    let path = config_dir.join("Defold").join("prefs.editor_settings");

    if !path.exists() {
        bail!("prefs.editor_settings file {path:?} could not be found");
    }

    let data = fs::read_to_string(&path)?;

    let mut config = Edn::from_str(&data).map_err(|err| anyhow::anyhow!(err.to_string()))?;

    config[":code"][":custom-editor"] = Edn::Str(
        create_runner_script(plugin_root, launch_config)?
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
