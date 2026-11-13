use std::path::Path;

use anyhow::{Context, Result, ensure};
use serde::Serialize;

use crate::{miniproto, resources};

#[derive(Debug, Serialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct GuiNodeEntry {
    pub id: String,
    pub from_location: String,
}

pub fn fetch_nodes_for(root_dir: &Path, script_path: &Path) -> Result<Vec<GuiNodeEntry>> {
    ensure!(
        root_dir.is_dir(),
        "invalid project root: {}",
        root_dir.display()
    );

    let script = resources::resource_path(root_dir, script_path).with_context(|| {
        format!(
            "{} must be in {}",
            script_path.display(),
            root_dir.display()
        )
    })?;

    let script = format!("/{script}");
    let mut nodes = Vec::new();

    for resource in resources::load(root_dir, &["gui"]) {
        if resource.message.first_string("script").as_deref() != Some(script.as_str()) {
            continue;
        }

        for value in resource.message.get("nodes") {
            let miniproto::Value::Message(node) = value else {
                continue;
            };

            if let Some(id) = node.first_string("id").filter(|id| !id.is_empty()) {
                nodes.push(GuiNodeEntry {
                    id,
                    from_location: format!("/{}", resource.path),
                });
            }
        }
    }

    nodes.sort();
    nodes.dedup();

    Ok(nodes)
}
