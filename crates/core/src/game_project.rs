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

    #[serde(skip_serializing_if = "Option::is_none")]
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
    fn rejects_projects_without_required_metadata() {
        for (source, expected) in [
            ("[library]\ninclude_dirs = api", "no [project] section"),
            (
                "[project]\nversion = 1.0",
                "no title field in [project] section",
            ),
        ] {
            let error = GameProject::try_from(source.to_string()).unwrap_err();
            assert!(error.to_string().contains(expected), "{error}");
        }
    }

    #[test]
    fn defaults_optional_dependencies_and_library() {
        let project = GameProject::try_from("[project]\ntitle = Minimal".to_string()).unwrap();

        assert_eq!(project.dependencies.len(), 0);
        assert!(project.library.is_none());

        let project = GameProject::try_from(
            "[project]\ntitle = Minimal\n[library]\nother = ignored".to_string(),
        )
        .unwrap();

        assert_eq!(project.library.unwrap().include_dirs.len(), 0);
    }

    #[test]
    fn trims_library_directories_and_filters_dependency_keys() {
        let project = GameProject::try_from(
            "[project]\ntitle = Library\ndependencies#1 = first.zip\ndependencies#2 = second.zip\ndependencies = ignored.zip\n[library]\ninclude_dirs = api, scripts/internal , resources"
                .to_string(),
        )
        .unwrap();

        assert_eq!(project.dependencies, ["first.zip", "second.zip"]);
        assert_eq!(
            project.library.unwrap().include_dirs,
            ["api", "scripts/internal", "resources"]
        );
    }

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
