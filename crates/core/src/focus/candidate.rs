use anyhow::{Context, Result};

use super::window::Window;

#[derive(Debug)]
pub struct Candidate {
    pub id: String,
    pub classes: Vec<String>,
    pub title: Option<String>,
}

/// Picks the window to focus, a class match wins over an exact title match
pub fn pick<'a>(candidates: &'a [Candidate], window: &Window) -> Option<&'a str> {
    let by_class = window
        .class
        .as_ref()
        .and_then(|class| candidates.iter().find(|c| c.classes.contains(class)));

    let by_title = || {
        window
            .title
            .as_ref()
            .and_then(|title| candidates.iter().find(|c| c.title.as_ref() == Some(title)))
    };

    by_class.or_else(by_title).map(|c| c.id.as_str())
}

pub const ERR_NO_WINDOW: &str = "no matching window found";

pub fn find<'a>(candidates: &'a [Candidate], window: &Window) -> Result<&'a str> {
    pick(candidates, window).context(ERR_NO_WINDOW)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::window::test_windows::*;

    #[test]
    fn picks_class_matches_before_title_matches() {
        let candidates = [
            Candidate {
                id: "1".into(),
                classes: vec![],
                title: Some("My Game".into()),
            },
            Candidate {
                id: "2".into(),
                classes: vec!["x".into(), "com.defold.nvim.p1".into()],
                title: Some("My Game".into()),
            },
        ];

        let both = Window {
            title: Some("My Game".into()),
            ..neovim()
        };

        assert_eq!(pick(&candidates, &both), Some("2"));
        assert_eq!(pick(&candidates, &game()), Some("1"));
        assert_eq!(pick(&candidates, &titled("My")), None);
    }
}
