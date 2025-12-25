use std::path::Path;
use std::{
    env,
    fs::{self, File, Permissions},
    path::PathBuf,
};

use anyhow::{Context, Result, bail};

use crate::{release_downloader, utils};

const EXECUTABLE_NAME: &str = "neovide";
const OWNER: &str = "neovide";
const REPOSITORY: &str = "neovide";

#[cfg(target_os = "linux")]
const ASSET_NAME: &str = "neovide-linux-x86_64.tar.gz";

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const ASSET_NAME: &str = "Neovide-x86_64-apple-darwin.dmg";

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const ASSET_NAME: &str = "Neovide-aarch64-apple-darwin.dmg";

#[cfg(target_os = "windows")]
const ASSET_NAME: &'static str = "neovide.exe.zip";

fn bin_dir() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim")
        .join("bin");

    Ok(dir)
}

fn path() -> Result<PathBuf> {
    let dir = bin_dir()?;

    fs::create_dir_all(&dir)?;

    Ok(match env::consts::OS {
        "linux" => dir.join("neovide"),
        "windows" => dir.join("neovide.exe"),
        "macos" => dir
            .join("Neovide.app")
            .join("Contents")
            .join("MacOS")
            .join("neovide"),
        _ => bail!("Unknown OS {}", env::consts::OS),
    })
}

#[cfg(target_os = "linux")]
fn install_neovide(downloaded_file: &Path) -> Result<()> {
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

    let neovide_path = parent_dir.join("neovide");

    if !neovide_path.exists() {
        bail!("Neovide doesnt exist after unpacking?");
    }

    fs::set_permissions(&neovide_path, Permissions::from_mode(0o700))?;

    utils::move_file(&neovide_path, &path()?)?;

    Ok(())
}

#[cfg(target_os = "macos")]
fn install_neovide(downloaded_file: &Path) -> Result<()> {
    use dmg::Attach;
    use fs_extra::dir;

    let handle = Attach::new(downloaded_file).with()?;

    tracing::debug!("Mounted .dmg at {:?}", handle.mount_point);

    let neovide_path = handle.mount_point.join("Neovide.app");

    let target_path = bin_dir()?.join("Neovide.app");

    if target_path.exists() {
        fs::remove_dir_all(&target_path)?;
    }

    dir::copy(
        &neovide_path,
        &target_path,
        &dir::CopyOptions::new().overwrite(true).copy_inside(true),
    )?;

    Ok(())
}

#[cfg(target_os = "windows")]
fn install_neovide(downloaded_file: &Path) -> Result<()> {
    use zip::ZipArchive;

    let parent_dir = downloaded_file
        .parent()
        .map(PathBuf::from)
        .context("could not get parent dir")?;

    let file = File::open(&downloaded_file)?;

    let mut archive = ZipArchive::new(file)?;
    archive.extract(&parent_dir)?;

    let neovide_path = parent_dir.join("neovide.exe");

    if !neovide_path.exists() {
        bail!("Neovide doesnt exist after unpacking?");
    }

    utils::move_file(&neovide_path, &path()?)?;

    Ok(())
}

pub fn install() -> Result<PathBuf> {
    release_downloader::install_with(
        OWNER,
        REPOSITORY,
        ASSET_NAME,
        EXECUTABLE_NAME,
        install_neovide,
        path,
        false,
    )
}
