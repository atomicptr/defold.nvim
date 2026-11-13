use std::{fs, path::Path};

use walkdir::WalkDir;

use crate::miniproto::{self, Message};

pub struct Resource {
    pub path: String,
    pub message: Message,
}

#[must_use]
pub fn resource_path(root_dir: &Path, file: &Path) -> Option<String> {
    let relative = file.strip_prefix(root_dir).ok()?;

    Some(
        relative
            .components()
            .map(|component| component.as_os_str().to_string_lossy())
            .collect::<Vec<_>>()
            .join("/"),
    )
}

pub fn load(root_dir: &Path, extensions: &[&str]) -> Vec<Resource> {
    let mut resources = Vec::new();

    let files = WalkDir::new(root_dir)
        .sort_by_file_name()
        .into_iter()
        .filter_entry(|entry| {
            entry.depth() == 0 || !entry.file_name().to_string_lossy().starts_with('.')
        })
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file());

    for entry in files {
        let file = entry.path();

        let has_extension = file
            .extension()
            .and_then(|ext| ext.to_str())
            .is_some_and(|ext| extensions.contains(&ext));

        if !has_extension {
            continue;
        }

        let Some(path) = resource_path(root_dir, file) else {
            continue;
        };

        match fs::read_to_string(file)
            .map_err(anyhow::Error::from)
            .and_then(|src| miniproto::parse(&src))
        {
            Ok(message) => resources.push(Resource { path, message }),
            Err(err) => tracing::error!("could not parse {}: {err:?}", file.display()),
        }
    }

    resources
}
