use std::{
    fs::{self, File},
    path::PathBuf,
    time::Duration,
};

use anyhow::{Context, Result, bail};
use version_compare::Version;
use zip::ZipArchive;

use crate::{github, project, utils};

const OWNER: &str = "astrochili";
const REPOSITORY: &str = "defold-annotations";

pub fn dir() -> Result<PathBuf> {
    let dir = project::deps_root()?.join("defold");
    Ok(dir)
}

fn version_path() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get data dir")?
        .join("defold.nvim")
        .join("meta");

    fs::create_dir_all(&dir)?;

    Ok(dir.join("defold_annotations_version"))
}

fn version() -> Result<String> {
    let file = version_path()?;

    if !file.exists() {
        bail!("Version not found");
    }

    Ok(fs::read_to_string(file)?)
}

fn is_update_available() -> Result<bool> {
    let defold_dir = dir()?;

    if !defold_dir.exists() {
        return Ok(true);
    }

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

    tracing::debug!("Defold Annotations Version {v} installed");

    let Some(installed) = Version::from(&v) else {
        return Ok(true);
    };

    let release = github::fetch_release(OWNER, REPOSITORY)?;

    tracing::debug!("Defold Annotations Version {} is newest", release.tag_name);

    let Some(current) = Version::from(&release.tag_name) else {
        return Ok(false);
    };

    Ok(current > installed)
}

pub fn install() -> Result<()> {
    if !is_update_available()? {
        return Ok(());
    }

    tracing::info!("Updating Defold annotations...");

    let defold_dir = dir()?;
    if defold_dir.exists() {
        fs::remove_dir_all(&defold_dir)?;
    }

    let (download_path, release) = github::download_release_matching(OWNER, REPOSITORY, |asset| {
        asset.name.starts_with("defold_api_")
    })?;

    let parent_dir = download_path.parent().context("could not get parent dir")?;

    tracing::info!("Found version {}", release.tag_name);

    let file = File::open(&download_path)?;

    let mut archive = ZipArchive::new(file)?;
    archive.extract(parent_dir)?;

    let defold_api_dir = parent_dir.join("defold_api");

    if !defold_api_dir.exists() {
        bail!(
            "Defold Annotations could not be found after downloading at {}",
            defold_api_dir.display()
        );
    }

    utils::move_file(&defold_api_dir, &defold_dir)?;
    fs::write(version_path()?, release.tag_name)?;

    github::clear_downloads(OWNER, REPOSITORY)?;

    Ok(())
}
