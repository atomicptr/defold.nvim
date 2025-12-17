use std::{
    fs::{self, File, Permissions},
    path::PathBuf,
};

use anyhow::{Context, Result, bail};
use defold_nvim_core::github;
use flate2::read::GzDecoder;
use tar::Archive;
use version_compare::Version;
use zip::ZipArchive;

#[cfg(target_os = "linux")]
use std::os::unix::fs::PermissionsExt;

const OWNER: &str = "neovide";
const REPOSITORY: &str = "neovide";

#[cfg(target_os = "linux")]
const NAME: &str = "neovide-linux-x86_64.tar.gz";

#[cfg(target_os = "macos")]
const NAME: &'static str = "not supported";

#[cfg(target_os = "windows")]
const NAME: &'static str = "neovide.exe.zip";

fn path() -> Result<PathBuf> {
    let dir = dirs::state_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("bin");

    fs::create_dir_all(&dir)?;

    let suffix = if cfg!(target_os = "windows") {
        ".exe"
    } else {
        ""
    };

    Ok(dir.join(format!("neovide{suffix}")))
}

fn version_path() -> Result<PathBuf> {
    let dir = dirs::state_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("meta");

    fs::create_dir_all(&dir)?;

    Ok(dir.join("neovide_version"))
}

fn version() -> Result<String> {
    let file = version_path()?;

    if !file.exists() {
        bail!("Version not found");
    }

    Ok(fs::read_to_string(file)?)
}

pub fn is_update_available() -> Result<bool> {
    // macos is unsupported
    if cfg!(target_os = "macos") {
        tracing::debug!("MacOS is not supported, no update available");
        return Ok(false);
    }

    let Ok(v) = version() else {
        return Ok(true);
    };

    tracing::debug!("Neovide Version {v} installed");

    let Some(installed) = Version::from(&v) else {
        return Ok(true);
    };

    let release = github::fetch_release(OWNER, REPOSITORY)?;

    tracing::debug!("Neovide Version {} is newest", release.tag_name);

    let Some(current) = Version::from(&release.tag_name) else {
        return Ok(false);
    };

    Ok(current > installed)
}

pub fn update_or_install() -> Result<PathBuf> {
    if !is_update_available()? {
        return path();
    }

    let (downloaded_file, release) = github::download_release(OWNER, REPOSITORY, NAME)?;

    tracing::debug!("New Neovide version found {}", release.tag_name);

    let parent_dir = downloaded_file
        .parent()
        .map(PathBuf::from)
        .context("could not get parent dir")?;

    let file = File::open(downloaded_file)?;

    if cfg!(target_os = "linux") {
        let tar = GzDecoder::new(file);
        let mut archive = Archive::new(tar);
        archive.unpack(&parent_dir)?;

        let neovide_path = parent_dir.join("neovide");

        if !neovide_path.exists() {
            bail!("Neovide doesnt exist after unpacking?");
        }

        fs::set_permissions(&neovide_path, Permissions::from_mode(0o700))?;

        fs::rename(neovide_path, path()?)?;
    } else if cfg!(target_os = "windows") {
        let mut archive = ZipArchive::new(file)?;
        archive.extract(&parent_dir)?;

        let neovide_path = parent_dir.join("neovide.exe");

        if !neovide_path.exists() {
            bail!("Neovide doesnt exist after unpacking?");
        }

        fs::rename(neovide_path, path()?)?;
    } else {
        bail!("Unsupported OS");
    }

    fs::write(version_path()?, release.tag_name)?;

    path()
}
