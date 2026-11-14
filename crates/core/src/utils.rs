use std::{
    fmt::Write,
    fs::{self, File},
    path::Path,
};

use anyhow::Result;
use sha3::{Digest, Sha3_256};

use crate::path;

#[must_use]
pub fn sha3(str: &str) -> String {
    let mut hasher = Sha3_256::new();
    hasher.update(str.as_bytes());

    hasher
        .finalize()
        .iter()
        .fold(String::with_capacity(64), |mut out, byte| {
            let _ = write!(out, "{byte:02x}");
            out
        })
}

pub fn classname(game_root: &Path) -> Result<String> {
    Ok(format!("com.defold.nvim.p{}", path::project_id(game_root)?))
}

pub fn move_file(from: &Path, to: &Path) -> Result<()> {
    if let Some(parent) = to.parent() {
        fs::create_dir_all(parent)?;
    }

    let is_dir = from.is_dir();

    if is_dir && to.exists() {
        fs::remove_dir_all(to)?;
    }

    if fs::rename(from, to).is_ok() {
        return Ok(());
    }

    // fs::rename fails across filesystems (e.g. from a tmpfs temp dir), so fall back to copy + delete
    if is_dir {
        copy_dir(from, to)?;
        fs::remove_dir_all(from)?;
    } else {
        fs::copy(from, to)?;
        fs::remove_file(from)?;
    }

    Ok(())
}

fn copy_dir(from: &Path, to: &Path) -> Result<()> {
    fs::create_dir_all(to)?;

    for entry in fs::read_dir(from)? {
        let entry = entry?;
        let source = entry.path();
        let destination = to.join(entry.file_name());

        if source.is_dir() {
            copy_dir(&source, &destination)?;
        } else {
            fs::copy(&source, &destination)?;
        }
    }

    Ok(())
}

pub fn unpack(archive: &Path, target: &Path) -> Result<()> {
    fs::create_dir_all(target)?;

    let name = archive.to_string_lossy();

    if name.ends_with(".zip") {
        zip::ZipArchive::new(File::open(archive)?)?.extract(target)?;
    } else if name.ends_with(".tar.gz") {
        tar::Archive::new(flate2::read::GzDecoder::new(File::open(archive)?)).unpack(target)?;
    } else {
        #[cfg(target_os = "macos")]
        if name.ends_with(".dmg") {
            use dmg::Attach;

            let handle = Attach::new(archive).with()?;

            for entry in fs::read_dir(&handle.mount_point)? {
                let entry = entry?;
                let destination = target.join(entry.file_name());
                let kind = entry.file_type()?;
                if kind.is_dir() {
                    copy_dir(&entry.path(), &destination)?;
                } else if kind.is_file() {
                    fs::copy(entry.path(), destination)?;
                }

                // Do not follow top-level links into the host filesystem (e.g. /Applications).
            }

            return Ok(());
        }

        anyhow::bail!("Unsupported archive: {}", archive.display());
    }

    Ok(())
}

#[must_use]
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
