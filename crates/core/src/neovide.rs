use std::{
    env,
    fs::{self, File, Permissions},
    path::PathBuf,
    time::Duration,
};

use anyhow::{Context, Result, bail};
use version_compare::Version;

use crate::github;
use crate::utils;

const OWNER: &str = "neovide";
const REPOSITORY: &str = "neovide";

#[cfg(target_os = "linux")]
const NAME: &str = "neovide-linux-x86_64.tar.gz";

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const NAME: &str = "Neovide-x86_64-apple-darwin.dmg";

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const NAME: &str = "Neovide-aarch64-apple-darwin.dmg";

#[cfg(target_os = "windows")]
const NAME: &'static str = "neovide.exe.zip";

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

fn version_path() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
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
    if !path()?.exists() {
        return Ok(true);
    }

    if !version_path()?.exists() {
        return Ok(true);
    }

    let Ok(v) = version() else {
        return Ok(true);
    };

    tracing::debug!("Neovide Version {v} installed");

    // if the version file is younger than a week dont bother
    let last_modified = version_path()?.metadata()?.modified()?;
    if last_modified.elapsed()? < Duration::from_hours(24 * 7) {
        return Ok(false);
    }

    // re-write the file again so that we only check once a week
    fs::write(version_path()?, &v)?;

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

pub fn install() -> Result<PathBuf> {
    if !is_update_available()? {
        return path();
    }

    let (downloaded_file, release) = github::download_release(OWNER, REPOSITORY, NAME)?;

    tracing::debug!("New Neovide version found {}", release.tag_name);

    let parent_dir = downloaded_file
        .parent()
        .map(PathBuf::from)
        .context("could not get parent dir")?;

    let file = File::open(&downloaded_file)?;

    #[cfg(target_os = "linux")]
    {
        use flate2::read::GzDecoder;
        use std::os::unix::fs::PermissionsExt;
        use tar::Archive;

        let tar = GzDecoder::new(file);
        let mut archive = Archive::new(tar);
        archive.unpack(&parent_dir)?;

        let neovide_path = parent_dir.join("neovide");

        if !neovide_path.exists() {
            bail!("Neovide doesnt exist after unpacking?");
        }

        fs::set_permissions(&neovide_path, Permissions::from_mode(0o700))?;

        utils::move_file(&neovide_path, &path()?)?;
    }

    #[cfg(target_os = "windows")]
    {
        use zip::ZipArchive;

        let mut archive = ZipArchive::new(file)?;
        archive.extract(&parent_dir)?;

        let neovide_path = parent_dir.join("neovide.exe");

        if !neovide_path.exists() {
            bail!("Neovide doesnt exist after unpacking?");
        }

        utils::move_file(&neovide_path, &path()?)?;
    }

    #[cfg(target_os = "macos")]
    {
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
    }

    fs::write(version_path()?, release.tag_name)?;

    github::clear_downloads(OWNER, REPOSITORY)?;

    path()
}
