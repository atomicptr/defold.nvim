use anyhow::{Context, Result};
use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::utils::sha3;

const NAME: &str = "defold.nvim";

pub fn data_dir() -> Result<PathBuf> {
    let base = if cfg!(windows) {
        dirs::data_local_dir()
    } else {
        dirs::data_dir()
    };

    base.context("could not get data dir").map(|p| p.join(NAME))
}

pub fn cache_dir() -> Result<PathBuf> {
    if cfg!(windows) {
        return dirs::data_local_dir()
            .context("could not get cache dir")
            .map(|p| p.join("Temp").join(format!("{NAME}-cache")));
    }

    dirs::cache_dir()
        .context("could not get cache dir")
        .map(|p| p.join(NAME))
}

pub fn bin_dir() -> Result<PathBuf> {
    Ok(data_dir()?.join("bin"))
}

pub fn logs_dir() -> Result<PathBuf> {
    Ok(data_dir()?.join("logs"))
}

pub struct ProjectPaths {
    pub data: PathBuf,
    pub deps: PathBuf,
    pub cache: PathBuf,
}

fn id_of(normalized_root: &str) -> String {
    sha3(normalized_root)[..8].to_string()
}

/// Short stable identifier of a game root, used for project directories and window classes
pub fn project_id(game_root: &Path) -> Result<String> {
    Ok(id_of(&normalize_root(game_root)?))
}

pub fn project_paths(game_root: &Path) -> Result<ProjectPaths> {
    paths_for(&normalize_root(game_root)?)
}

fn paths_for(normalized_root: &str) -> Result<ProjectPaths> {
    let id = id_of(normalized_root);
    let data = data_dir()?.join("projects").join(&id);

    Ok(ProjectPaths {
        deps: data.join("deps"),
        cache: cache_dir()?.join("projects").join(&id),
        data,
    })
}

pub fn ensure_project_dir(game_root: &Path) -> Result<ProjectPaths> {
    let root = normalize_root(game_root)?;
    let paths = paths_for(&root)?;
    fs::create_dir_all(&paths.data)?;
    fs::write(paths.data.join("root"), root)?;

    Ok(paths)
}

fn normalize_root(game_root: &Path) -> Result<String> {
    let path = fs::canonicalize(game_root).or_else(|_| std::path::absolute(game_root))?;
    let path = path.to_str().context("game root is not valid UTF-8")?;

    Ok(normalize_root_str(path, cfg!(windows)))
}

fn normalize_root_str(path: &str, windows: bool) -> String {
    if !windows {
        return path.to_string();
    }

    let path = path.replace('/', "\\");

    // canonicalize returns verbatim paths like \\?\C:\ or \\?\UNC\server\share
    let path = if let Some(unc) = path.strip_prefix(r"\\?\UNC\") {
        format!(r"\\{unc}")
    } else if let Some(local) = path.strip_prefix(r"\\?\") {
        local.to_string()
    } else {
        path
    };

    let path = if path.len() > 3 {
        path.trim_end_matches('\\')
    } else {
        &path
    };

    // NTFS is case insensitive
    path.to_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_unix_paths_as_is() {
        assert_eq!(normalize_root_str("/home/x/Game", false), "/home/x/Game");
    }

    #[test]
    fn normalizes_windows_paths() {
        for (input, expected) in [
            (r"\\?\C:\Users\X\Game", r"c:\users\x\game"),
            (r"c:/users/x/game/", r"c:\users\x\game"),
            (r"C:\Users\X\Game", r"c:\users\x\game"),
            (r"\\?\UNC\Server\Share\Game", r"\\server\share\game"),
            (r"C:\", r"c:\"),
        ] {
            assert_eq!(normalize_root_str(input, true), expected, "{input}");
        }
    }

    #[test]
    fn resolves_symlinks_and_relative_segments() {
        let base = std::env::temp_dir().join(format!("defold-nvim-path-{}", std::process::id()));
        let game = base.join("game");
        fs::create_dir_all(&game).unwrap();

        let id = project_id(&game).unwrap();
        assert_eq!(project_id(&game.join("..").join("game")).unwrap(), id);

        #[cfg(unix)]
        {
            let link = base.join("link");
            std::os::unix::fs::symlink(&game, &link).unwrap();
            assert_eq!(project_id(&link).unwrap(), id);
        }

        fs::remove_dir_all(&base).unwrap();
        assert_eq!(id.len(), 8);
    }
}
