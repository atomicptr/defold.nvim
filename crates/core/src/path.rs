use anyhow::{Context, Result};
use std::path::PathBuf;
use walkdir::DirEntry;

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

pub fn is_hidden(entry: &DirEntry) -> bool {
    entry
        .file_name()
        .to_str()
        .is_some_and(|s| s.starts_with('.'))
}
