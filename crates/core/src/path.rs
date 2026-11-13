use anyhow::{Context, Result};
use std::path::PathBuf;

pub fn data_dir() -> Result<PathBuf> {
    let base = if cfg!(windows) {
        dirs::data_local_dir()
    } else {
        dirs::data_dir()
    };

    base.context("could not get data dir")
        .map(|p| p.join("defold.nvim"))
}

pub fn cache_dir() -> Result<PathBuf> {
    let (base, name) = if cfg!(windows) {
        (dirs::data_local_dir(), "defold.nvim-cache")
    } else {
        (dirs::cache_dir(), "defold.nvim")
    };

    base.context("could not get cache dir")
        .map(|p| p.join(name))
}
