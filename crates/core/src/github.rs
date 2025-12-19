use std::{
    env::temp_dir,
    fs::{self, File},
    io,
    path::PathBuf,
};

use anyhow::{Result, bail};
use serde::{Deserialize, Serialize};

use crate::cache;

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
    let url = format!("https://api.github.com/repos/{owner}/{repo}/releases/latest");

    if let Some(str) = cache::get(&url)
        && let Ok(res) = serde_json::from_str(&str)
    {
        tracing::debug!("Serving {url} from cache");
        return Ok(res);
    }

    let client = reqwest::blocking::Client::new();
    let res = client.get(&url).header("User-Agent", USER_AGENT).send()?;

    let release: Release = res.json()?;

    cache::set(&url, &serde_json::to_string(&release)?)?;

    Ok(release)
}

pub fn clear_downloads(owner: &str, repo: &str) -> Result<()> {
    let temp = temp_dir()
        .join("defold.nvim")
        .join("download")
        .join(owner)
        .join(repo);

    tracing::debug!("Deleting {}...", &temp.display());

    fs::remove_dir_all(temp)?;

    Ok(())
}

pub fn download_release_matching<F>(
    owner: &str,
    repo: &str,
    matching: F,
) -> Result<(PathBuf, Release)>
where
    F: Fn(&Asset) -> bool,
{
    let temp = temp_dir()
        .join("defold.nvim")
        .join("download")
        .join(owner)
        .join(repo);
    fs::create_dir_all(&temp)?;

    let release = fetch_release(owner, repo)?;

    let Some(asset) = release.assets.iter().find(|asset| matching(asset)) else {
        bail!("Could not find asset for {owner}/{repo}");
    };

    let download_file = temp.join(&asset.name);

    if download_file.exists() {
        return Ok((download_file, release));
    }

    let mut res = reqwest::blocking::get(&asset.browser_download_url)?;
    res.error_for_status_ref()?;

    let mut file = File::create(&download_file)?;
    io::copy(&mut res, &mut file)?;

    Ok((download_file, release))
}

pub fn download_release(owner: &str, repo: &str, name: &str) -> Result<(PathBuf, Release)> {
    download_release_matching(owner, repo, |asset| asset.name == name)
        .map_err(|_| anyhow::anyhow!("Could not find asset {name} for {owner}/{repo}"))
}
