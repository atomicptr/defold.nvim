use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::{defold_annotations, game_project::GameProject, utils::sha3};
use anyhow::{Context, Result, bail};

pub fn deps_root() -> Result<PathBuf> {
    let dir = dirs::state_dir()
        .context("could not get state dir")?
        .join("defold.nvim")
        .join("deps");
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

fn deps_dir(game_root: &Path) -> Result<PathBuf> {
    let hash = sha3(&game_root.display().to_string());
    let ident = hash.get(..8).context("could not create hash")?;
    let dir = deps_root()?.join(ident);
    fs::create_dir_all(&dir)?;
    Ok(dir)
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

    // TODO: delete dependencies if force redownload is set
    // TODO: download dependencies
    // TODO: check for unused dependencies

    // let game_project = GameProject::load_from_path(game_project_path);
    // println!("{game_project:?}");
    // println!("{:?}", deps_dir(game_root));

    Ok(())
}
