use crate::{github, path, release_downloader, utils};
use anyhow::Result;
use std::{
    fs::{self},
    path::{Path, PathBuf},
};

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
    let dir = path::data_dir()?.join("bin");

    fs::create_dir_all(&dir)?;

    Ok(dir.join(exe_name()))
}

fn matches_version(installed: &str, required: &str) -> bool {
    installed.trim().trim_start_matches('v') == required
}

fn install() -> Result<PathBuf> {
    let path = local_path()?;
    let version = utils::version();

    if path.is_file()
        && release_downloader::version(EXECUTABLE_NAME)
            .is_ok_and(|installed| matches_version(&installed, &version))
    {
        return Ok(path);
    }

    let tag = format!("v{version}");
    let (downloaded_file, release) =
        github::download_release(OWNER, REPOSITORY, ASSET_NAME, Some(&tag))?;

    utils::move_file(&downloaded_file, &path)?;

    #[cfg(any(target_os = "linux", target_os = "macos"))]
    {
        use std::{fs::Permissions, os::unix::fs::PermissionsExt};
        fs::set_permissions(&path, Permissions::from_mode(0o700))?;
    }

    fs::write(
        release_downloader::version_path(EXECUTABLE_NAME)?,
        &release.tag_name,
    )?;

    github::clear_downloads(OWNER, REPOSITORY, &release.tag_name)?;

    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::matches_version;

    #[test]
    fn requires_exact_release_including_downgrades() {
        assert!(matches_version("v0.11.0\n", "0.11.0"));
        assert!(matches_version("0.11.0", "0.11.0"));
        assert!(!matches_version("0.10.0", "0.11.0"));
        assert!(!matches_version("0.12.0", "0.11.0"));
        assert!(!matches_version("", "0.11.0"));
    }
}
