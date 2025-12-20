use std::{
    fs::{self, File},
    io::Write,
    path::{Path, PathBuf},
};

use crate::{
    defold_annotations,
    game_project::GameProject,
    script_api,
    utils::{self, sha3},
};
use anyhow::{Context, Result, bail};
use walkdir::WalkDir;
use zip::ZipArchive;

fn ident(string: &str) -> Result<String> {
    let hash = sha3(string);
    let ident_str = hash.get(..8).context("could not create hash")?;
    Ok(ident_str.to_string())
}

pub fn deps_root() -> Result<PathBuf> {
    let dir = dirs::data_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("deps");
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

fn deps_dir(game_root: &Path) -> Result<PathBuf> {
    let dir = deps_root()?
        .join("project")
        .join(ident(&game_root.display().to_string())?);
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

pub fn list_dependency_dirs(game_root: &Path) -> Result<Vec<PathBuf>> {
    let mut deps = Vec::new();

    if let Ok(annotations) = defold_annotations::dir()
        && annotations.exists()
    {
        deps.push(annotations);
    }

    if let Ok(dep_dirs) = deps_dir(game_root) {
        for entry in fs::read_dir(dep_dirs)? {
            let path = entry?.path();

            if !path.is_dir() {
                continue;
            }

            deps.push(path);
        }
    }

    Ok(deps)
}

pub fn install_dependencies(game_root: &Path, force_redownload: bool) -> Result<()> {
    let game_project_path = game_root.join("game.project");

    if !game_project_path.exists() {
        bail!(
            "Could not find game.project file at {}",
            game_project_path.display()
        );
    }

    defold_annotations::install()?;

    let proj_deps_dir = deps_dir(game_root)?;

    if force_redownload {
        fs::remove_dir_all(&proj_deps_dir)?;
    }

    let game_project = GameProject::load_from_path(&game_project_path)?;

    for dep_url in &game_project.dependencies {
        if let Err(err) = install_dependency(dep_url, &proj_deps_dir) {
            tracing::error!("Could not download dependency {dep_url} because: {err:?}");
        }
    }

    // delete unused dirs
    let dep_dirs = fs::read_dir(&proj_deps_dir)?
        .filter_map(Result::ok)
        .map(|f| f.path())
        .filter(|f| f.is_dir());

    'outer: for dir in dep_dirs {
        let Some(name) = dir
            .file_name()
            .and_then(|s| s.to_str())
            .map(std::string::ToString::to_string)
        else {
            continue;
        };

        for dep in &game_project.dependencies {
            let dep_ident = ident(dep)?;

            if name == dep_ident {
                continue 'outer;
            }
        }

        tracing::debug!("Removing unused dependency dir {}", dir.display());
        fs::remove_dir_all(dir)?;
    }

    utils::delete_empty_dirs_from(game_root)?;

    Ok(())
}

fn install_dependency(url: &str, project_deps_dir: &Path) -> Result<()> {
    let target_dir = project_deps_dir.join(ident(url)?);

    if target_dir.exists() {
        tracing::debug!("Dependency {url} does already exist, skipping...");
        return Ok(());
    }

    tracing::info!("Downloading {url} to {}...", target_dir.display());

    let downloaded_file = utils::download(url)?;

    tracing::debug!("Downloaded to {}", downloaded_file.display());

    let parent_dir = downloaded_file
        .parent()
        .context("could not get parent dir of downloaded file")?;

    let file = File::open(&downloaded_file)?;
    let mut archive = ZipArchive::new(file)?;
    archive.extract(parent_dir)?;

    tracing::debug!("Extracted to {}", parent_dir.display());

    let game_project_file = find_game_project(parent_dir)?;
    let game_root = game_project_file
        .parent()
        .context("could not get parent dir of game.project")?;

    let game_project = GameProject::load_from_path(&game_project_file)?;

    let Some(library) = &game_project.library else {
        utils::clear_download(url)?;
        bail!("Dependency {url} does not contain key library.include_dirs");
    };

    if library.include_dirs.is_empty() {
        utils::clear_download(url)?;
        bail!("Dependency {url} does not contain any library.include_dirs");
    }

    for include_dir in &library.include_dirs {
        let include_dir_path = game_root.join(include_dir);
        let include_dir_target = target_dir.join(include_dir);

        if !include_dir_path.exists() {
            tracing::warn!(
                "Dependency {url} has specified include dir {include_dir} but it doesn't actually exist at {}. Skipping...",
                include_dir_path.display()
            );
            continue;
        }

        compile_script_api_files(&include_dir_path)?;
        copy_files(&include_dir_path, &include_dir_target, "lua")?;
    }

    utils::clear_download(url)?;

    Ok(())
}

fn find_game_project(root_dir: &Path) -> Result<PathBuf> {
    for file in WalkDir::new(root_dir)
        .into_iter()
        .filter_map(Result::ok)
        .map(walkdir::DirEntry::into_path)
        .filter(|p| p.is_file())
    {
        if let Some(filename) = file.file_name().and_then(|s| s.to_str())
            && filename == "game.project"
        {
            tracing::debug!("Found game.project at {}", file.display());
            return Ok(file);
        }
    }

    bail!("Could not find game.project file in {}", root_dir.display());
}

fn find_files_with_ext(root_dir: &Path, ext: &str) -> Vec<PathBuf> {
    WalkDir::new(root_dir)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file())
        .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some(ext))
        .map(|e| e.path().to_owned())
        .collect()
}

fn compile_script_api_files(from_dir: &Path) -> Result<()> {
    let files = find_files_with_ext(from_dir, "script_api");

    for file in &files {
        let Some(stem) = file.file_stem() else {
            continue;
        };

        let target_path = file.with_file_name(format!("{}.lua", stem.to_str().unwrap()));

        tracing::debug!(
            "Compiling {} to {}...",
            file.display(),
            target_path.display()
        );

        let input = fs::read_to_string(file)?;
        let output = script_api::compile(&input)?;

        let mut file = File::create(target_path)?;
        file.write_all(output.as_bytes())?;
    }

    Ok(())
}

fn copy_files(from_dir: &Path, to_dir: &Path, ext: &str) -> Result<()> {
    for file in find_files_with_ext(from_dir, ext) {
        let relative_path = file.strip_prefix(from_dir)?;
        let target_path = to_dir.join(relative_path);
        let target_parent = target_path.parent().context("could not get path parent")?;

        fs::create_dir_all(target_parent)?;

        tracing::debug!("Copying {} to {}", file.display(), target_path.display());
        fs::copy(file, target_path)?;
    }

    Ok(())
}
