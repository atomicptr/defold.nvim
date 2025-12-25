use anyhow::{Context, Result, bail};
use std::{
    fs,
    path::{Path, PathBuf},
    time::Duration,
};
use version_compare::Version;

use crate::github;

const CACHE_DURATION: u64 = 8; // hours

pub fn make_path(executable_name: &str) -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim")
        .join("bin");

    fs::create_dir_all(&dir)?;

    let suffix = if cfg!(target_os = "windows") {
        ".exe"
    } else {
        ""
    };

    Ok(dir.join(format!("{executable_name}{suffix}")))
}

pub fn version_path(executable_name: &str) -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim")
        .join("meta");

    fs::create_dir_all(&dir)?;

    Ok(dir.join(format!("{executable_name}_version")))
}

pub fn version(executable_name: &str) -> Result<String> {
    let file = version_path(executable_name)?;

    if !file.exists() {
        bail!("Version not found");
    }

    Ok(fs::read_to_string(file)?)
}

pub fn is_update_available<P>(
    owner: &str,
    repository: &str,
    executable_name: &str,
    path_fn: P,
) -> Result<bool>
where
    P: Fn() -> Result<PathBuf>,
{
    if !path_fn()?.exists() {
        return Ok(true);
    }

    if !version_path(executable_name)?.exists() {
        return Ok(true);
    }

    let Ok(v) = version(executable_name) else {
        return Ok(true);
    };

    tracing::debug!("{executable_name} version {v} installed");

    // if the version file is younger than cache duration
    let last_modified = version_path(executable_name)?.metadata()?.modified()?;
    if last_modified.elapsed()? < Duration::from_hours(CACHE_DURATION) {
        return Ok(false);
    }

    // re-write the file again so that we only check once
    fs::write(version_path(executable_name)?, &v)?;

    let Some(installed) = Version::from(&v) else {
        return Ok(true);
    };

    let release = github::fetch_release(owner, repository)?;

    tracing::debug!("{executable_name} version {} is newest", release.tag_name);

    let Some(current) = Version::from(&release.tag_name) else {
        return Ok(false);
    };

    Ok(current > installed)
}

fn download_and_install<F, P>(
    owner: &str,
    repository: &str,
    asset_name: &str,
    executable_name: &str,
    install_fn: F,
    path_fn: P,
    force_redownload: bool,
) -> Result<PathBuf>
where
    F: Fn(&Path) -> Result<()>,
    P: Fn() -> Result<PathBuf>,
{
    if !force_redownload && !is_update_available(owner, repository, executable_name, &path_fn)? {
        return path_fn();
    }

    let (downloaded_file, release) = github::download_release(owner, repository, asset_name)?;

    tracing::debug!("New {executable_name} version found {}", release.tag_name);

    install_fn(&downloaded_file)?;

    fs::write(version_path(executable_name)?, release.tag_name)?;

    github::clear_downloads(owner, repository)?;

    path_fn()
}

pub fn install_with<F, P>(
    owner: &str,
    repository: &str,
    asset_name: &str,
    executable_name: &str,
    install_fn: F,
    path_fn: P,
    force_redownload: bool,
) -> Result<PathBuf>
where
    F: Fn(&Path) -> Result<()>,
    P: Fn() -> Result<PathBuf>,
{
    match download_and_install(
        owner,
        repository,
        asset_name,
        executable_name,
        &install_fn,
        &path_fn,
        force_redownload,
    ) {
        Ok(path) => Ok(path),
        Err(err) => {
            tracing::error!("Could not install {executable_name}: {err:?}");

            // if file exists but we couldnt install just return it
            match path_fn()? {
                p if p.exists() => return Ok(p),
                _ => (),
            }

            Err(err)
        }
    }
}
