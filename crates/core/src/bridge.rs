use anyhow::{Context, Result, bail};
use std::{
    fs::{self},
    path::{Path, PathBuf},
    time::Duration,
};
use version_compare::Version;

use crate::github;

#[cfg(target_os = "windows")]
const EXE_SUFFIX: &'static str = ".exe";

#[cfg(not(target_os = "windows"))]
const EXE_SUFFIX: &str = "";

#[cfg(target_os = "linux")]
const NAME: &str = "linux-x86-defold-nvim-bridge";

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const NAME: &str = "macos-x86-defold-nvim-bridge";

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const NAME: &str = "macos-arm-defold-nvim-bridge";

#[cfg(target_os = "windows")]
const NAME: &str = "windows-x86-defold-nvim-bridge";

const OWNER: &str = "atomicptr";
const REPOSITORY: &str = "defold.nvim";

pub fn path(plugin_root: &Path) -> Result<PathBuf> {
    let exe = exe_name();

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

    install()
}

fn exe_name() -> String {
    format!("defold-nvim-bridge{EXE_SUFFIX}")
}

fn local_path() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("bin");

    fs::create_dir_all(&dir)?;

    Ok(dir.join(exe_name()))
}

fn version_path() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("meta");

    fs::create_dir_all(&dir)?;

    Ok(dir.join("bridge_version"))
}

fn version() -> Result<String> {
    let file = version_path()?;

    if !file.exists() {
        bail!("Version not found");
    }

    Ok(fs::read_to_string(file)?)
}

fn is_update_available() -> Result<bool> {
    if version_path()?.exists() {
        // if the version file is younger than a week dont bother
        let last_modified = version_path()?.metadata()?.modified()?;
        if last_modified.elapsed()? < Duration::from_hours(24 * 7) {
            return Ok(false);
        }
    }

    let Ok(v) = version() else {
        return Ok(true);
    };

    // re-write the file again so that we only check once a week
    fs::write(version_path()?, &v)?;

    tracing::debug!("Bridge Version {v} installed");

    let Some(installed) = Version::from(&v) else {
        return Ok(true);
    };

    let release = github::fetch_release(OWNER, REPOSITORY)?;

    tracing::debug!("Bridge Version {} is newest", release.tag_name);

    let Some(current) = Version::from(&release.tag_name) else {
        return Ok(false);
    };

    Ok(current > installed)
}

fn install() -> Result<PathBuf> {
    let path = local_path()?;

    if path.exists() && !is_update_available()? {
        return local_path();
    }

    let (downloaded_file, release) = github::download_release(OWNER, REPOSITORY, NAME)?;

    tracing::debug!("New Bridge version found {}", release.tag_name);

    fs::rename(downloaded_file, &path)?;
    fs::write(version_path()?, release.tag_name)?;

    #[cfg(any(target_os = "linux", target_os = "macos"))]
    {
        use std::{fs::Permissions, os::unix::fs::PermissionsExt};
        fs::set_permissions(&path, Permissions::from_mode(0o700))?;
    }

    github::clear_downloads(OWNER, REPOSITORY)?;

    Ok(path)
}
