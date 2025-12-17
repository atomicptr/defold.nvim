use crate::utils::sha3;
use anyhow::{Context, Result};
use std::{fs, path::PathBuf, time::Duration};

fn cache_dir() -> Result<PathBuf> {
    let dir = dirs::cache_dir()
        .context("could not get cache dir")?
        .join("defold.nvim")
        .join("cache");

    fs::create_dir_all(&dir)?;

    Ok(dir)
}

pub fn get(key: &str) -> Option<String> {
    let Ok(dir) = cache_dir() else {
        tracing::error!("Could not get cache dir");
        return None;
    };

    let path = dir.join(sha3(key));

    if path.exists() {
        let modified = path.metadata().ok()?.modified().ok()?;

        if modified.elapsed().ok()? < Duration::from_secs(3600) {
            return fs::read_to_string(&path).ok();
        } else {
            fs::remove_file(&path).ok();
        }
    }

    None
}

pub fn set(key: &str, value: &str) {
    let Ok(dir) = cache_dir() else {
        tracing::error!("Could not get cache dir");
        return;
    };

    let path = dir.join(sha3(key));
    fs::write(path, value).ok();
}
