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
    let windows = parse_windows(&run(executable, &["msg", "--json", "windows"], true)?)?;
    let id = find(&windows, window)?;

    run(
        executable,
        &["msg", "action", "focus-window", "--id", id],
        false,
    )?;

    Ok(())
}

#[derive(Deserialize)]
struct NiriWindow {
    id: u64,
    title: Option<String>,
    app_id: Option<String>,
}

fn parse_windows(output: &str) -> Result<Vec<Candidate>> {
    let windows: Vec<NiriWindow> = serde_json::from_str(output)?;

    Ok(windows
        .into_iter()
        .map(|w| Candidate {
            id: w.id.to_string(),
            classes: w.app_id.into_iter().collect(),
            title: w.title,
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::candidate::pick;
    use crate::focus::window::test_windows::*;

    #[test]
    fn reads_niri_windows() {
        let windows = r#"[
            {"id":1,"title":"My Game 2","app_id":"dmengine","workspace_id":1,"is_focused":false},
            {"id":2,"title":null,"app_id":null},
            {"id":3,"title":"nvim","app_id":"com.defold.nvim.p1"},
            {"id":4,"title":"My Game","app_id":"dmengine"}
        ]"#;

        let candidates = parse_windows(windows).unwrap();
        assert_eq!(pick(&candidates, &neovim()), Some("3"));
        assert_eq!(pick(&candidates, &game()), Some("4"));
        assert!(parse_windows("nope").is_err());
    }
}
