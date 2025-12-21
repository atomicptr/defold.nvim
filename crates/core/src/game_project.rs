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

#[cfg(test)]
mod tests {
    use crate::game_project::GameProject;
    use pretty_assertions::assert_eq;

    #[test]
    fn test_parse_game_project() {
        let input = r"[project]
title = My Fancy Game
dependencies#1 = https://example.com/dependency1.zip
dependencies#2 = https://example.com/dependency2.zip

[library]
include_dirs = my_fancy_game";

        let g: GameProject = input
            .to_string()
            .try_into()
            .expect("could not parse game.project file");

        assert_eq!("My Fancy Game", g.title);
        assert_eq!(2, g.dependencies.len());
        assert_eq!(
            vec![
                "https://example.com/dependency1.zip",
                "https://example.com/dependency2.zip"
            ],
            g.dependencies
        );
        assert!(g.library.is_some());
        assert_eq!(1, g.library.as_ref().unwrap().include_dirs.len());
        assert_eq!(
            vec!["my_fancy_game"],
            g.library.as_ref().unwrap().include_dirs
        );
    }
}
