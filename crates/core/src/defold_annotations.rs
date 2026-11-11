use std::{
    fs::{self, File},
    io::{self, Read, Seek},
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result, ensure};
use zip::ZipArchive;

use crate::{editor, github, path, project, utils};

const OWNER: &str = "defold";
const REPOSITORY: &str = "defold";

fn root() -> Result<PathBuf> {
    Ok(project::deps_root()?.join("defold"))
}

fn version_path() -> Result<PathBuf> {
    let dir = path::data_dir()?.join("meta");
    fs::create_dir_all(&dir)?;

    Ok(dir.join("defold_annotations_version"))
}

fn version_dir(root: &Path, version: &str) -> Result<PathBuf> {
    Ok(root.join(editor::parse_version(version)?))
}

pub fn cached_dir() -> Result<PathBuf> {
    let version = fs::read_to_string(version_path()?)?;

    version_dir(&root()?, version.trim())
}

fn extract_annotations<R: Read + Seek>(reader: R, target: &Path) -> Result<()> {
    let mut archive = ZipArchive::new(reader)?;
    fs::create_dir_all(target)?;

    let mut copied = 0;
    for index in 0..archive.len() {
        let mut entry = archive.by_index(index)?;
        let path = entry
            .enclosed_name()
            .context("could not parse path in Defold docs archive")?;

        if !entry.is_file() || path.extension().is_none_or(|ext| ext != "lua") {
            continue;
        }

        let Some(name) = path.file_name() else {
            tracing::warn!("Skipping annotation without a filename: {}", path.display());
            continue;
        };

        let mut output = File::create(target.join(name))?;

        io::copy(&mut entry, &mut output)?;
        copied += 1;
    }

    ensure!(copied > 0, "No Lua files in Defold documentation archive");

    Ok(())
}

pub fn ensure(version: Option<&str>) -> Result<PathBuf> {
    match install(version) {
        Ok(path) => Ok(path),
        Err(err) => {
            if version.is_none()
                && let Ok(cached) = cached_dir()
                && cached.is_dir()
            {
                return Ok(cached);
            }

            Err(err)
        }
    }
}

pub fn install(version: Option<&str>) -> Result<PathBuf> {
    match version {
        Some(version) => install_version(&root()?, version),
        None => {
            let release = github::fetch_release(OWNER, REPOSITORY)?;
            let target = install_version(&root()?, &release.tag_name)?;

            fs::write(version_path()?, release.tag_name)?;

            Ok(target)
        }
    }
}

fn install_version(root: &Path, version: &str) -> Result<PathBuf> {
    let target = version_dir(root, version)?;
    if target.is_dir() {
        return Ok(target);
    }

    tracing::info!("Installing Defold {version} annotations");

    let (download, release) =
        github::download_release(OWNER, REPOSITORY, "ref-doc.zip", Some(version))?;

    let nonce = SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos();
    let staging = std::env::temp_dir()
        .join("defold.nvim")
        .join(format!("annotations-{}-{nonce}", std::process::id()));

    let result = (|| -> Result<()> {
        extract_annotations(File::open(download)?, &staging)?;
        utils::move_file(&staging, &target)?;
        Ok(())
    })();

    if staging.exists()
        && let Err(err) = fs::remove_dir_all(&staging)
    {
        tracing::warn!("Could not remove annotation staging directory: {err}");
    }

    if result.is_err() && target.is_dir() {
        fs::remove_dir_all(&target).context("Could not remove incomplete annotations")?;
    }

    result?;
    github::clear_downloads(OWNER, REPOSITORY, &release.tag_name)?;
    Ok(target)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Cursor, Write};
    use zip::{ZipWriter, write::SimpleFileOptions};

    struct TestDir(PathBuf);

    impl TestDir {
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let path = std::env::temp_dir().join(format!(
                "defold-annotations-test-{}-{nonce}",
                std::process::id()
            ));
            fs::create_dir(&path).unwrap();
            Self(path)
        }
    }

    impl Drop for TestDir {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).unwrap();
        }
    }

    fn archive(files: &[&str]) -> Cursor<Vec<u8>> {
        let mut writer = ZipWriter::new(Cursor::new(Vec::new()));
        for name in files {
            writer
                .start_file(*name, SimpleFileOptions::default())
                .unwrap();
            writer.write_all(b"---@meta\n").unwrap();
        }

        writer.finish().unwrap()
    }

    #[test]
    fn validates_version_paths() {
        let root = Path::new("annotations");
        for version in ["1.13.2", "1.14.1"] {
            assert_eq!(version_dir(root, version).unwrap(), root.join(version));
        }

        for version in [
            "",
            "1.14",
            "1.14.1-beta",
            "1.14.1-alpha",
            "../1.14.1",
            "/1.14.1",
        ] {
            assert_eq!(
                version_dir(root, version).unwrap_err().to_string(),
                format!("invalid version {version}")
            );
        }
    }

    #[test]
    fn extracts_all_lua_files() {
        let temp = TestDir::new();
        let target = temp.0.join("1.14.1");
        let reader = archive(&[
            "doc/custom.lua",
            "doc/custom.script_api",
            "doc/custom.json",
            "doc/custom.editor_script",
            "other/extra.lua",
            "doc/nested/nested.lua",
            "root.lua",
        ]);
        extract_annotations(reader, &target).unwrap();

        assert_eq!(fs::read_dir(&target).unwrap().count(), 4);
        for name in ["custom.lua", "extra.lua", "nested.lua", "root.lua"] {
            assert_eq!(fs::read_to_string(target.join(name)).unwrap(), "---@meta\n");
        }
    }

    #[test]
    fn rejects_archive_without_lua_files() {
        let temp = TestDir::new();
        let err = extract_annotations(archive(&["doc/go.json"]), &temp.0).unwrap_err();
        assert!(err.to_string().contains("No Lua files"));
    }

    #[test]
    fn rejects_unsafe_archive_paths() {
        let temp = TestDir::new();
        assert!(extract_annotations(archive(&["../escape.lua"]), &temp.0).is_err());
    }

    #[test]
    fn reuses_installed_version_without_network() {
        let temp = TestDir::new();
        let target = version_dir(&temp.0, "1.14.0").unwrap();
        fs::create_dir(&target).unwrap();
        fs::write(target.join("go.lua"), "cached").unwrap();

        assert_eq!(install_version(&temp.0, "1.14.0").unwrap(), target);
        assert_eq!(fs::read_to_string(target.join("go.lua")).unwrap(), "cached");
        assert_eq!(fs::read_dir(&temp.0).unwrap().count(), 1);
    }

    #[test]
    #[ignore = "requires network and isolated XDG data/cache directories under DEFOLD_ANNOTATIONS_SMOKE_ROOT"]
    fn installs_latest_stable_release() {
        let sandbox = PathBuf::from(std::env::var("DEFOLD_ANNOTATIONS_SMOKE_ROOT").unwrap());
        assert!(path::data_dir().unwrap().starts_with(&sandbox));
        assert!(path::cache_dir().unwrap().starts_with(&sandbox));

        let (latest_archive, _) =
            github::download_release(OWNER, REPOSITORY, "ref-doc.zip", None).unwrap();

        let (pinned_archive, _) =
            github::download_release(OWNER, REPOSITORY, "ref-doc.zip", Some("1.14.0")).unwrap();

        assert!(latest_archive.starts_with(std::env::temp_dir()));
        assert_ne!(latest_archive, pinned_archive);

        let selected = install(None).unwrap();
        assert!(pinned_archive.is_file());
        assert_eq!(cached_dir().unwrap(), selected);
        assert!(selected.join("go.lua").is_file());
        assert!(selected.join("vmath.lua").is_file());
        let modified = selected
            .join("go.lua")
            .metadata()
            .unwrap()
            .modified()
            .unwrap();

        assert_eq!(ensure(None).unwrap(), selected);
        assert_eq!(
            selected
                .join("go.lua")
                .metadata()
                .unwrap()
                .modified()
                .unwrap(),
            modified
        );
        let pinned = install(Some("1.14.0")).unwrap();
        assert_eq!(pinned.file_name().unwrap(), "1.14.0");
        assert!(pinned.join("go.lua").is_file());
        assert_eq!(cached_dir().unwrap(), selected);
        let modified = pinned
            .join("go.lua")
            .metadata()
            .unwrap()
            .modified()
            .unwrap();
        assert_eq!(install(Some("1.14.0")).unwrap(), pinned);
        assert_eq!(
            pinned
                .join("go.lua")
                .metadata()
                .unwrap()
                .modified()
                .unwrap(),
            modified
        );
        println!(
            "Installed and reused {} and {}",
            selected.display(),
            pinned.display()
        );
    }
}
