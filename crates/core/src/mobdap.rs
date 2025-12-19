use std::{
    fs::{self, File, Permissions},
    path::PathBuf,
    time::Duration,
};

use crate::github;
use anyhow::{Context, Result, bail};
use version_compare::Version;

const OWNER: &str = "atomicptr";
const REPOSITORY: &str = "mobdap";

#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
const NAME: &str = "mobdap-linux-amd64.tar.gz";

#[cfg(all(target_os = "linux", target_arch = "aarch64"))]
const NAME: &str = "mobdap-linux-arm64.tar.gz";

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const NAME: &str = "mobdap-macos-amd64.tar.gz";

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const NAME: &str = "mobdap-macos-arm64.tar.gz";

#[cfg(target_os = "windows")]
const NAME: &str = "mobdap-windows-amd64.zip";

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

    Ok(dir.join(format!("mobdap{suffix}")))
}

fn version_path() -> Result<PathBuf> {
    let dir = dirs::state_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("meta");

    fs::create_dir_all(&dir)?;

    Ok(dir.join("mobdap_version"))
}

fn version() -> Result<String> {
    let file = version_path()?;

    if !file.exists() {
        bail!("Version not found");
    }

    Ok(fs::read_to_string(file)?)
}

pub fn is_update_available() -> Result<bool> {
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

    tracing::debug!("Mobdap Version {v} installed");

    let Some(installed) = Version::from(&v) else {
        return Ok(true);
    };

    let release = github::fetch_release(OWNER, REPOSITORY)?;

    tracing::debug!("Mobdap Version {} is newest", release.tag_name);

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

    tracing::debug!("New Mobdap version found {}", release.tag_name);

    let parent_dir = downloaded_file
        .parent()
        .map(PathBuf::from)
        .context("could not get parent dir")?;

    let file = File::open(downloaded_file)?;

    #[cfg(any(target_os = "linux", target_os = "macos"))]
    {
        use flate2::read::GzDecoder;
        use std::os::unix::fs::PermissionsExt;
        use tar::Archive;

        let tar = GzDecoder::new(file);
        let mut archive = Archive::new(tar);
        archive.unpack(&parent_dir)?;

        let mobdap_path = parent_dir.join("mobdap");

        if !mobdap_path.exists() {
            bail!("Mobdap doesnt exist after unpacking?");
        }

        fs::set_permissions(&mobdap_path, Permissions::from_mode(0o700))?;

        fs::rename(mobdap_path, path()?)?;
    }

    #[cfg(target_os = "windows")]
    {
        use zip::ZipArchive;

        let mut archive = ZipArchive::new(file)?;
        archive.extract(&parent_dir)?;

        let mobdap_path = parent_dir.join("mobdap.exe");

        if !mobdap_path.exists() {
            bail!("mobdap doesnt exist after unpacking?");
        }

        fs::rename(mobdap_path, path()?)?;
    }

    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        bail!("Unsupported operating system");
    }

    fs::write(version_path()?, release.tag_name)?;

    github::clear_downloads(OWNER, REPOSITORY)?;

    path()
}
