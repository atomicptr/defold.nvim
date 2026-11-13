use std::{
    fs,
    path::{Component, Path, PathBuf},
};

use anyhow::{Context, Result, bail};
use walkdir::WalkDir;

use crate::{game_project::GameProject, path, script_api, utils::project_id as ident};

pub fn list_dependency_dirs(game_root: &Path) -> Result<Vec<PathBuf>> {
    let dir = path::data_dir()?
        .join("deps")
        .join("project")
        .join(ident(&game_root.display().to_string()));

    let entries = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(err.into()),
    };

    let mut deps = Vec::new();

    for entry in entries {
        let path = entry?.path();
        if path.is_dir() {
            deps.push(path);
        }
    }

    Ok(deps)
}

pub fn install_dependency(source: &Path, target: &Path) -> Result<Vec<String>> {
    tracing::debug!(
        "Installing dependency from {} to {}",
        source.display(),
        target.display()
    );

    let project_file = find_game_project(source)?;
    let root = project_file
        .parent()
        .context("game.project has no parent directory")?;

    tracing::debug!("Reading dependency project {}", project_file.display());

    let project = GameProject::load_from_path(&project_file)?;
    let library = project
        .library
        .context("Dependency has no library.include_dirs")?;

    if library.include_dirs.is_empty() {
        bail!("Dependency has no library.include_dirs");
    }

    let canonical_root = fs::canonicalize(root)?;
    let mut skipped = Vec::new();

    for include_dir in library.include_dirs {
        let from = root.join(&include_dir);

        // symlinked directories could still point outside of the dependency
        let escapes = !is_safe_include_dir(&include_dir)
            || fs::canonicalize(&from).is_ok_and(|from| !from.starts_with(&canonical_root));

        if escapes {
            tracing::warn!("Skipping unsafe dependency include directory: {include_dir}");
            skipped.push(include_dir);
            continue;
        }

        if !from.is_dir() {
            tracing::warn!(
                "Dependency include directory does not exist: {}",
                from.display()
            );
            continue;
        }

        for entry in WalkDir::new(&from) {
            let entry = entry?;

            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();

            let compile = match path.extension().and_then(|extension| extension.to_str()) {
                Some("lua") => false,
                Some("script_api") if !path.with_extension("lua").exists() => true,
                _ => continue,
            };

            let mut destination = target.join(&include_dir).join(path.strip_prefix(&from)?);

            if compile {
                destination.set_extension("lua");
            }

            fs::create_dir_all(
                destination
                    .parent()
                    .context("Lua file has no parent directory")?,
            )?;

            if compile {
                tracing::debug!("Compiling {} to {}", path.display(), destination.display());

                let input = fs::read_to_string(path)?;
                let output = script_api::compile(&input)
                    .with_context(|| format!("Could not compile {}", path.display()))?;

                fs::write(destination, output)?;
            } else {
                tracing::debug!("Copying {} to {}", path.display(), destination.display());
                fs::copy(path, destination)?;
            }
        }
    }

    fs::create_dir_all(target)?;

    Ok(skipped)
}

fn is_safe_include_dir(include_dir: &str) -> bool {
    let path = Path::new(include_dir);

    !include_dir.is_empty()
        && !include_dir.contains(['\\', ':'])
        && path
            .components()
            .all(|component| matches!(component, Component::Normal(_) | Component::CurDir))
}

fn find_game_project(source: &Path) -> Result<PathBuf> {
    for entry in WalkDir::new(source).sort_by_key(|entry| entry.file_type().is_dir()) {
        let entry = entry?;
        if entry.file_type().is_file() && entry.file_name() == "game.project" {
            return Ok(entry.into_path());
        }
    }

    bail!(
        "No game.project in dependency directory {}",
        source.display()
    );
}

#[cfg(test)]
mod tests {
    use super::is_safe_include_dir;

    #[test]
    fn accepts_only_relative_include_dirs_inside_the_dependency() {
        for dir in ["api", "scripts/internal", "./api", "a.b/c"] {
            assert!(is_safe_include_dir(dir), "{dir}");
        }

        for dir in [
            "",
            "..",
            "../outside",
            "api/../../x",
            "/tmp/x",
            r"..\x",
            r"C:\x",
            "C:/x",
        ] {
            assert!(!is_safe_include_dir(dir), "{dir}");
        }
    }
}
