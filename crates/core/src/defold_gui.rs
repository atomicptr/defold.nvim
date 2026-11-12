use std::{
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result, ensure};
use serde::Serialize;
use walkdir::WalkDir;

use crate::{miniproto, path};

#[derive(Debug, Serialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct GuiNodeEntry {
    pub id: String,
    pub from_location: String,
}

pub fn fetch_nodes_for(root_dir: &PathBuf, script_path: &Path) -> Result<Vec<GuiNodeEntry>> {
    ensure!(
        root_dir.is_dir(),
        "invalid project root: {}",
        root_dir.display()
    );

    let script = script_path
        .strip_prefix(root_dir)
        .with_context(|| {
            format!(
                "{} must be in {}",
                script_path.display(),
                root_dir.display()
            )
        })?
        .to_string_lossy()
        .replace('\\', "/");

    let script = format!("/{script}");
    let mut nodes = Vec::new();

    for entry in WalkDir::new(root_dir)
        .into_iter()
        .filter_entry(|entry| !path::is_hidden(entry))
    {
        let entry = entry?;
        let file = entry.path();

        if !entry.file_type().is_file() || file.extension().is_none_or(|ext| ext != "gui") {
            continue;
        }

        let message = match fs::read_to_string(file)
            .map_err(anyhow::Error::from)
            .and_then(|src| miniproto::parse(&src))
        {
            Ok(message) => message,
            Err(err) => {
                tracing::error!("could not parse GUI file {}: {err:?}", file.display());
                continue;
            }
        };

        if message.first_string("script").as_deref() != Some(script.as_str()) {
            continue;
        }

        let location = file
            .strip_prefix(root_dir)?
            .to_string_lossy()
            .replace('\\', "/");

        for value in message.get("nodes") {
            let miniproto::Value::Message(node) = value else {
                continue;
            };

            if let Some(id) = node.first_string("id").filter(|id| !id.is_empty()) {
                nodes.push(GuiNodeEntry {
                    id,
                    from_location: format!("/{location}"),
                });
            }
        }
    }

    nodes.sort();
    nodes.dedup();

    Ok(nodes)
}
