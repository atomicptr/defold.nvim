use std::path::Path;
use std::{
    fs::{self, File, Permissions},
    path::PathBuf,
};

use crate::release_downloader::{self, make_path};
use crate::utils;
use anyhow::{Context, Result, bail};

const EXECUTABLE_NAME: &str = "mobdap";
const OWNER: &str = "atomicptr";
const REPOSITORY: &str = "mobdap";

#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
const ASSET_NAME: &str = "mobdap-linux-amd64.tar.gz";

#[cfg(all(target_os = "linux", target_arch = "aarch64"))]
const ASSET_NAME: &str = "mobdap-linux-arm64.tar.gz";

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const ASSET_NAME: &str = "mobdap-macos-amd64.tar.gz";

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const ASSET_NAME: &str = "mobdap-macos-arm64.tar.gz";

#[cfg(target_os = "windows")]
const ASSET_NAME: &str = "mobdap-windows-amd64.zip";

fn path() -> Result<PathBuf> {
    make_path(EXECUTABLE_NAME)
}

#[cfg(any(target_os = "linux", target_os = "macos"))]
fn install_mobdap(downloaded_file: &Path) -> Result<()> {
    use flate2::read::GzDecoder;
    use std::os::unix::fs::PermissionsExt;
    use tar::Archive;

    let parent_dir = downloaded_file
        .parent()
        .map(PathBuf::from)
        .context("could not get parent dir")?;

    let file = File::open(downloaded_file)?;

    let tar = GzDecoder::new(file);
    let mut archive = Archive::new(tar);
    archive.unpack(&parent_dir)?;

    let mobdap_path = parent_dir.join("mobdap");

    if !mobdap_path.exists() {
        bail!("Mobdap doesnt exist after unpacking?");
    }

    fs::set_permissions(&mobdap_path, Permissions::from_mode(0o700))?;

    utils::move_file(&mobdap_path, &path()?)?;

    Ok(())
}

#[cfg(target_os = "windows")]
fn install_mobdap(downloaded_file: &Path) -> Result<()> {
    use zip::ZipArchive;

    let parent_dir = downloaded_file
        .parent()
        .map(PathBuf::from)
        .context("could not get parent dir")?;

    let file = File::open(downloaded_file)?;

    let mut archive = ZipArchive::new(file)?;
    archive.extract(&parent_dir)?;

    let mobdap_path = parent_dir.join("mobdap.exe");

    if !mobdap_path.exists() {
        bail!("mobdap doesnt exist after unpacking?");
    }

    utils::move_file(&mobdap_path, &path()?)?;

    Ok(())
}

pub fn install() -> Result<PathBuf> {
    release_downloader::install_with(
        OWNER,
        REPOSITORY,
        ASSET_NAME,
        EXECUTABLE_NAME,
        install_mobdap,
        path,
        false,
    )
}
