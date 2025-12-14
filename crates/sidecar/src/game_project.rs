use std::{fs, path::PathBuf};

use anyhow::{Context, Result, bail};
use ini::Ini;
use mlua::UserData;
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct GameProject {
    pub title: String,
    pub dependencies: Vec<String>,
}

impl GameProject {
    pub fn load_from_path(path: PathBuf) -> Result<GameProject> {
        if !path.exists() {
            bail!("game.project file {path:?} could not be found");
        }

        GameProject::try_from(fs::read_to_string(path)?)
    }
}

impl UserData for GameProject {}

impl TryFrom<String> for GameProject {
    type Error = anyhow::Error;

    fn try_from(value: String) -> std::result::Result<Self, Self::Error> {
        let proj = Ini::load_from_str(value.as_str())?;

        let project_section = proj
            .section(Some("project"))
            .context("invalid game.project: no [project] section")?;

        let title = project_section
            .get("title")
            .context("invalid game.project: no title field in [project] section")?
            .to_string();

        let dependencies = project_section
            .iter()
            .filter(|(k, _)| k.starts_with("dependencies#"))
            .map(|(_, v)| v.to_string())
            .collect();

        Ok(GameProject {
            title,
            dependencies,
        })
    }
}
