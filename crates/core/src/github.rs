use std::{
    env::temp_dir,
    fs::{self},
    path::PathBuf,
};

use anyhow::{Result, bail};
use serde::{Deserialize, Serialize};

use crate::{cache, utils};

const USER_AGENT: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36";

#[derive(Debug, Serialize, Deserialize)]
pub struct Asset {
    pub name: String,
    pub browser_download_url: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Release {
    pub tag_name: String,
    pub assets: Vec<Asset>,
}

pub fn fetch_release(owner: &str, repo: &str) -> Result<Release> {
    fetch_release_version(owner, repo, None)
}

pub fn fetch_release_version(owner: &str, repo: &str, version: Option<&str>) -> Result<Release> {
    let url = match version {
        Some(version) => url::Url::parse(&format!(
            "https://api.github.com/repos/{owner}/{repo}/releases/tags/{version}"
        ))?,
        None => url::Url::parse(&format!(
            "https://api.github.com/repos/{owner}/{repo}/releases/latest"
        ))?,
    };
    let url = url.as_str();

    tracing::debug!("Github: Fetching release {owner}/{repo}");

    if let Some(str) = cache::get(url)
        && let Ok(res) = serde_json::from_str::<Release>(&str)
    {
        tracing::debug!("Github: Found {}, serving from cache", res.tag_name);
        return Ok(res);
    }

    let client = reqwest::blocking::Client::new();
    let res = client
        .get(url)
        .header("User-Agent", USER_AGENT)
        .send()?
        .error_for_status()?;

    let release: Release = res.json()?;

    tracing::debug!("Github: Found {}", release.tag_name);

    cache::set(url, &serde_json::to_string(&release)?)?;

    Ok(release)
}

fn download_dir(owner: &str, repo: &str, version: &str) -> PathBuf {
    temp_dir()
        .join("defold.nvim")
        .join("download")
        .join(owner)
        .join(repo)
        .join(utils::sha3(version))
}

pub fn clear_downloads(owner: &str, repo: &str, version: &str) -> Result<()> {
    let temp = download_dir(owner, repo, version);

    tracing::debug!("Deleting {}...", &temp.display());

    fs::remove_dir_all(temp)?;

    Ok(())
}

pub fn download_release_matching<F>(
    owner: &str,
    repo: &str,
    version: Option<&str>,
    matching: F,
) -> Result<(PathBuf, Release)>
where
    F: Fn(&Asset) -> bool,
{
    let release = fetch_release_version(owner, repo, version)?;
    let temp = download_dir(owner, repo, &release.tag_name);
    fs::create_dir_all(&temp)?;

    let Some(asset) = release.assets.iter().find(|asset| matching(asset)) else {
        bail!("Could not find asset for {owner}/{repo}");
    };

    let download_file = temp.join(&asset.name);

    if download_file.exists() {
        return Ok((download_file, release));
    }

    let result = utils::download_to(&asset.browser_download_url, &download_file);
    if result.is_err() && download_file.exists() {
        fs::remove_file(&download_file)?;
    }
    result?;

    Ok((download_file, release))
}

pub fn download_release(
    owner: &str,
    repo: &str,
    name: &str,
    version: Option<&str>,
) -> Result<(PathBuf, Release)> {
    download_release_matching(owner, repo, version, |asset| asset.name == name).map_err(|err| {
        anyhow::anyhow!("Could not find asset {name} for {owner}/{repo} because: {err:?}")
    })
}
