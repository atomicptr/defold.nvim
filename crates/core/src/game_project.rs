use std::{fs, path::Path};

use anyhow::{Context, Result, bail};
use ini::Ini;
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct Library {
    pub include_dirs: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct GameProject {
    pub title: String,
    pub dependencies: Vec<String>,
    pub library: Option<Library>,
}

impl GameProject {
    pub fn load_from_path(path: &Path) -> Result<GameProject> {
        if !path.exists() {
            bail!("game.project file {} could not be found", path.display());
        }

        GameProject::try_from(fs::read_to_string(path)?)
    }
}

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

        let mut library = None;

        if let Some(library_section) = proj.section(Some("library")) {
            library = Some(Library {
                include_dirs: library_section
                    .get("include_dirs")
                    .map(|s| s.split(',').map(|s| s.trim().to_string()).collect())
                    .unwrap_or_default(),
            });
        }

        Ok(GameProject {
            title,
            dependencies,
            library,
        })
    }
}
