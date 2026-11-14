use std::path::Path;

use anyhow::Result;
use serde::Deserialize;

use crate::focus::{
    Failure,
    candidate::{Candidate, find},
    command::run,
    window::Window,
};

pub fn focus(executable: &Path, window: &Window) -> Result<(), Failure> {
    let windows = parse_windows(&run(executable, &["-t", "get_tree"], true)?)?;
    let id = find(&windows, window)?;

    run(executable, &[format!("[con_id={id}] focus")], false)?;

    Ok(())
}

#[derive(Deserialize)]
struct SwayNode {
    id: u64,
    name: Option<String>,
    app_id: Option<String>,
    window_properties: Option<SwayWindowProperties>,
    #[serde(default)]
    nodes: Vec<SwayNode>,
    #[serde(default)]
    floating_nodes: Vec<SwayNode>,
}

#[derive(Deserialize)]
struct SwayWindowProperties {
    class: Option<String>,
}

fn parse_windows(output: &str) -> Result<Vec<Candidate>> {
    fn collect(node: SwayNode, candidates: &mut Vec<Candidate>) {
        let class = node.window_properties.and_then(|p| p.class);

        // containers and workspaces have neither, Wayland windows use `app_id`, XWayland ones `window_properties`
        if node.app_id.is_some() || class.is_some() {
            candidates.push(Candidate {
                id: node.id.to_string(),
                classes: node.app_id.into_iter().chain(class).collect(),
                title: node.name,
            });
        }

        for child in node.nodes.into_iter().chain(node.floating_nodes) {
            collect(child, candidates);
        }
    }

    let mut candidates = Vec::new();
    collect(serde_json::from_str(output)?, &mut candidates);
    Ok(candidates)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::candidate::pick;
    use crate::focus::window::test_windows::*;

    #[test]
    fn reads_sway_tree() {
        let tree = r#"{
            "id": 1, "type": "root", "name": "root",
            "nodes": [{
                "id": 2, "type": "output", "name": "DP-1",
                "nodes": [{
                    "id": 3, "type": "workspace", "name": "1",
                    "nodes": [
                        {"id": 10, "type": "con", "name": "nvim", "app_id": "com.defold.nvim.p1", "nodes": []},
                        {"id": 11, "type": "con", "name": null, "nodes": [
                            {"id": 12, "type": "con", "name": "My Game", "app_id": null,
                             "window_properties": {"class": "dmengine", "instance": "dmengine"}, "nodes": []}
                        ]}
                    ],
                    "floating_nodes": [
                        {"id": 13, "type": "floating_con", "name": "Other", "app_id": "other", "nodes": []}
                    ]
                }]
            }]
        }"#;

        let candidates = parse_windows(tree).unwrap();
        let ids: Vec<_> = candidates.iter().map(|c| c.id.as_str()).collect();

        assert_eq!(ids, ["10", "12", "13"]);
        assert_eq!(pick(&candidates, &neovim()), Some("10"));
        assert_eq!(pick(&candidates, &game()), Some("12"));
        assert_eq!(pick(&candidates, &titled("Other")), Some("13"));
        assert!(parse_windows("[]").is_err());
    }
}
