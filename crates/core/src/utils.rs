use std::{
    env::temp_dir,
    fs::{self, File},
    io,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use fs_extra::{
    dir::{self, move_dir},
    file,
};
use sha3::{Digest, Sha3_256};
use url::Url;
use walkdir::WalkDir;

pub fn sha3(str: &str) -> String {
    let mut hasher = Sha3_256::new();
    hasher.update(str.as_bytes());
    let result = hasher.finalize();

    format!("{:x}", result)
}

pub fn project_id(root_dir: &str) -> Result<String> {
    Ok(sha3(root_dir)
        .get(0..8)
        .context("could not create project id")?
        .to_string())
}

pub fn classname(root_dir: &str) -> Result<String> {
    Ok(format!("com.defold.nvim.{}", project_id(root_dir)?))
}

pub fn download(url: &str) -> Result<PathBuf> {
    let download_dir = temp_dir()
        .join("defold.nvim")
        .join("download")
        .join(sha3(url).get(..8).context("could not make hash")?);
    fs::create_dir_all(&download_dir)?;

    let parsed_url = Url::parse(url)?;

    let filename = parsed_url
        .path_segments()
        .and_then(std::iter::Iterator::last)
        .unwrap_or("file");

    let download_file = download_dir.join(filename);

    download_to(url, &download_file)?;

    Ok(download_file)
}

pub fn clear_download(url: &str) -> Result<()> {
    let download_root_dir = temp_dir().join("defold.nvim").join("download");
    let download_dir = download_root_dir.join(sha3(url).get(..8).context("could not make hash")?);
    fs::remove_dir_all(download_dir)?;
    delete_empty_dirs_from(&download_root_dir)?;
    Ok(())
}

pub fn download_to(url: &str, path: &Path) -> Result<()> {
    tracing::debug!("Downloading {url} to {}...", path.display());

    let mut res = reqwest::blocking::get(url)?;
    res.error_for_status_ref()?;

    let mut file = File::create(path)?;
    io::copy(&mut res, &mut file)?;
    Ok(())
}

pub fn delete_empty_dirs_from(root_dir: &Path) -> Result<()> {
    for entry in WalkDir::new(root_dir)
        .contents_first(true)
        .into_iter()
        .filter_map(Result::ok)
    {
        let path = entry.path();

        if path.is_dir() && fs::read_dir(path)?.next().is_none() {
            fs::remove_dir(path)?;
        }
    }
    Ok(())
}

// Apparently fs::rename doesnt work on tmpfs
pub fn move_file(from: &Path, to: &Path) -> Result<()> {
    if let Some(parent) = to.parent() {
        fs::create_dir_all(parent)?;
    }

    if from.is_dir() {
        dir::move_dir(from, to, &dir::CopyOptions::new().overwrite(true))?;
    } else {
        file::move_file(from, to, &file::CopyOptions::new().overwrite(true))?;
    }

    Ok(())
}
