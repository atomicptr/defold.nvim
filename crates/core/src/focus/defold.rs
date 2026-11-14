use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};

use super::{Focus, Subject, switcher::switch, window::Window};
use crate::{game_project::GameProject, utils::classname};

fn ensure_project(root_dir: &Path) -> Result<PathBuf> {
    let game_project = root_dir.join("game.project");

    if !game_project.exists() {
        bail!(
            "Could not find game.project file in {}: Not a valid Defold directory",
            root_dir.display()
        );
    }

    Ok(game_project)
}

pub fn focus_neovim(root_dir: &Path, focus: &Focus) -> Result<()> {
    ensure_project(root_dir)?;

    if *focus == Focus::Off {
        tracing::debug!("Focus switching to Neovim is disabled");
        return Ok(());
    }

    // the launcher only assigns a class on Linux
    let class = if cfg!(target_os = "linux") {
        Some(classname(
            root_dir
                .to_str()
                .context("could not convert path to string")?,
        ))
    } else {
        None
    };

    switch(
        focus,
        &Window {
            subject: Subject::Neovim,
            class,
            title: None,
            app: None,
        },
    )
}

pub fn focus_game(root_dir: &Path, focus: &Focus) -> Result<()> {
    let game_project = ensure_project(root_dir)?;

    if *focus == Focus::Off {
        tracing::debug!("Focus switching to the game is disabled");
        return Ok(());
    }

    let title = GameProject::load_from_path(&game_project)?.title;

    // on macOS the game process is named after the project title
    let app = cfg!(target_os = "macos").then(|| title.clone());

    switch(
        focus,
        &Window {
            subject: Subject::Game,
            class: None,
            title: Some(title),
            app,
        },
    )
}
