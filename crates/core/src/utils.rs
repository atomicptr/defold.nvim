use std::{
    fs::{self, File},
    path::Path,
};

use anyhow::{Context, Result};
use fs_extra::{dir, file};
use sha3::{Digest, Sha3_256};

#[must_use]
pub fn sha3(str: &str) -> String {
    let mut hasher = Sha3_256::new();
    hasher.update(str.as_bytes());
    let result = hasher.finalize();

    hex::encode(result)
}

pub fn project_id(root_dir: &str) -> Result<String> {
    Ok(sha3(root_dir)
        .get(0..8)
        .context("could not create project id")?
        .to_string())
}

pub fn classname(root_dir: &str) -> Result<String> {
    Ok(format!("com.defold.nvim.p{}", project_id(root_dir)?))
}

// Apparently fs::rename doesnt work on tmpfs
pub fn move_file(from: &Path, to: &Path) -> Result<()> {
    if let Some(parent) = to.parent() {
        fs::create_dir_all(parent)?;
    }

    if from.is_dir() {
        if to.exists() {
            fs::remove_dir_all(to)?;
        }

        dir::move_dir(
            from,
            to,
            &dir::CopyOptions::new().overwrite(true).copy_inside(true),
        )?;
    } else {
        file::move_file(from, to, &file::CopyOptions::new().overwrite(true))?;
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
                    dir::copy(
                        entry.path(),
                        destination,
                        &dir::CopyOptions::new().copy_inside(true),
                    )?;
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

pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
