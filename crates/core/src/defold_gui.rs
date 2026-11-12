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

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct TestDir(PathBuf);

    impl TestDir {
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let root = std::env::temp_dir()
                .join(format!("defold-gui-test-{}-{nonce}", std::process::id()));
            fs::create_dir(&root).unwrap();
            Self(root)
        }
    }

    impl Drop for TestDir {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).unwrap();
        }
    }

    #[test]
    fn collects_only_direct_nodes_from_associated_guis() {
        let temp = TestDir::new();
        fs::write(
            temp.0.join("main.gui"),
            r#"
script: "/controller.gui_script"
nodes { id: "root" }
nodes { id: "label" parent: "root" }
nodes { id: "label" }
nodes { id: "" }
nodes { type: TYPE_BOX }
layouts { name: "landscape" nodes { id: "layout_only" } }
"#,
        )
        .unwrap();
        fs::write(
            temp.0.join("shared.gui"),
            r#"
script: "/controller.gui_script"
nodes { id: "root" }
"#,
        )
        .unwrap();
        fs::write(
            temp.0.join("other.gui"),
            r#"
script: "/other.gui_script"
nodes { id: "unrelated" }
"#,
        )
        .unwrap();
        fs::write(temp.0.join("broken.gui"), "nodes {").unwrap();
        fs::create_dir(temp.0.join(".hidden")).unwrap();
        fs::write(
            temp.0.join(".hidden/hidden.gui"),
            r#"
script: "/controller.gui_script"
nodes { id: "hidden" }
"#,
        )
        .unwrap();

        let nodes = fetch_nodes_for(&temp.0, &temp.0.join("controller.gui_script")).unwrap();
        assert_eq!(
            nodes,
            vec![
                GuiNodeEntry {
                    id: "label".into(),
                    from_location: "/main.gui".into()
                },
                GuiNodeEntry {
                    id: "root".into(),
                    from_location: "/main.gui".into()
                },
                GuiNodeEntry {
                    id: "root".into(),
                    from_location: "/shared.gui".into()
                },
            ]
        );
    }

    #[test]
    fn unattached_script_has_no_nodes() {
        let temp = TestDir::new();
        fs::write(temp.0.join("main.gui"), "nodes { id: \"root\" }").unwrap();
        assert!(
            fetch_nodes_for(&temp.0, &temp.0.join("main.gui_script"))
                .unwrap()
                .is_empty()
        );
    }
}
