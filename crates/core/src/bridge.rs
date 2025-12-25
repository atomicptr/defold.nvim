use anyhow::{Context, Result};
use std::{
    fs::{self},
    path::{Path, PathBuf},
};
use version_compare::Version;

use crate::{release_downloader, utils};

const EXECUTABLE_NAME: &str = "defold-nvim-bridge";
const OWNER: &str = "atomicptr";
const REPOSITORY: &str = "defold.nvim";

#[cfg(target_os = "linux")]
const ASSET_NAME: &str = "linux-x86-defold-nvim-bridge";

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const ASSET_NAME: &str = "macos-x86-defold-nvim-bridge";

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const ASSET_NAME: &str = "macos-arm-defold-nvim-bridge";

#[cfg(target_os = "windows")]
const ASSET_NAME: &str = "windows-x86-defold-nvim-bridge";

pub fn path(plugin_root: Option<&Path>) -> Result<PathBuf> {
    let exe = exe_name();

    if let Some(plugin_root) = plugin_root
        && plugin_root.exists()
    {
        let candidates = [
            plugin_root.join("target").join("debug").join(&exe),
            plugin_root.join("target").join("release").join(&exe),
        ];

        if let Some(bridge_path) = candidates.into_iter().find(|p| p.exists()) {
            return Ok(bridge_path);
        }
    }

    install()
}

fn exe_name() -> String {
    if cfg!(target_os = "windows") {
        "defold-nvim-bridge.exe".to_string()
    } else {
        "defold-nvim-bridge".to_string()
    }
}

fn local_path() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim")
        .join("bin");

    fs::create_dir_all(&dir)?;

    Ok(dir.join(exe_name()))
}

fn install() -> Result<PathBuf> {
    let min_version = utils::version();
    let min_version = Version::from(&min_version);
    let curr_version = release_downloader::version(EXECUTABLE_NAME);
    let curr_version = curr_version
        .as_ref()
        .map(|v| Version::from(v))
        .ok()
        .flatten();

    release_downloader::install_with(
        OWNER,
        REPOSITORY,
        ASSET_NAME,
        EXECUTABLE_NAME,
        |downloaded_file| {
            let path = local_path()?;

            utils::move_file(downloaded_file, &path)?;

            #[cfg(any(target_os = "linux", target_os = "macos"))]
            {
                use std::{fs::Permissions, os::unix::fs::PermissionsExt};
                fs::set_permissions(&path, Permissions::from_mode(0o700))?;
            }

            Ok(())
        },
        local_path,
        match (min_version, curr_version) {
            (Some(mv), Some(cv)) => mv > cv,
            _ => false,
        },
    )?;

    local_path()
}
