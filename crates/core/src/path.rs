use anyhow::{Context, Result};
use std::path::PathBuf;

pub fn data_dir() -> Result<PathBuf> {
    dirs::data_dir()
        .context("could not get data dir")
        .map(|p| p.join("defold.nvim"))
}

pub fn cache_dir() -> Result<PathBuf> {
    dirs::cache_dir()
        .context("could not get cache dir")
        .map(|p| p.join("defold.nvim"))
}
