use std::path::Path;

use crate::focus::{Failure, candidate::ERR_NO_WINDOW, command::run, window::Window};

pub fn focus(executable: &Path, window: &Window) -> Result<(), Failure> {
    let searches = [("--class", &window.class), ("--name", &window.title)];

    // kdotool succeeds even if nothing matches, so search before activating
    for (flag, value) in searches {
        let Some(value) = value else { continue };

        let ids = run(executable, &search_args(flag, value), true)?;

        if let Some(id) = ids.lines().map(str::trim).find(|id| !id.is_empty()) {
            run(executable, &["windowactivate", id], false)?;
            return Ok(());
        }
    }

    Err(anyhow::anyhow!(ERR_NO_WINDOW).into())
}

fn search_args(flag: &str, value: &str) -> Vec<String> {
    let mut pattern = String::from("^");

    for c in value.chars() {
        if "\\^$.|?*+()[]{}`\"'".contains(c) {
            pattern.push('\\');
        }

        pattern.push(c);
    }

    pattern.push('$');

    vec![
        "search".into(),
        "--case-sensitive".into(),
        flag.into(),
        pattern,
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_literal_kdotool_patterns() {
        assert_eq!(
            search_args("--name", r"a (b) ${c}`\")[3],
            r"^a \(b\) \$\{c\}\`\\$"
        );

        assert_eq!(
            search_args("--name", r#"My "Game"); x("'s"#)[3],
            r#"^My \"Game\"\); x\(\"\'s$"#
        );
    }
}
