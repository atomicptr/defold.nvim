use std::path::Path;

use anyhow::{Context, Result, bail};
use serde::Deserialize;

use crate::focus::{
    Failure,
    candidate::{Candidate, find},
    command::run,
    window::Window,
};

const EXTENSION_HINT: &str = "the GNOME extension 'Window Calls' is required, see https://extensions.gnome.org/extension/4724/window-calls/";

pub fn focus(executable: &Path, window: &Window) -> Result<(), Failure> {
    let output = match run(executable, &args("List", None), true) {
        Err(err) if is_missing_extension(&format!("{err:#}")) => {
            return Err(Failure::Unavailable(EXTENSION_HINT));
        }
        output => output?,
    };

    let windows = parse_windows(&output)?;
    let id = find(&windows, window)?;

    run(executable, &args("Activate", Some(id)), false)?;

    Ok(())
}

fn args(method: &str, id: Option<&str>) -> Vec<String> {
    let mut args: Vec<String> = [
        "call",
        "--session",
        "--dest",
        "org.gnome.Shell",
        "--object-path",
        "/org/gnome/Shell/Extensions/Windows",
        "--method",
    ]
    .into_iter()
    .map(Into::into)
    .collect();

    args.push(format!("org.gnome.Shell.Extensions.Windows.{method}"));
    args.extend(id.map(Into::into));
    args
}

fn is_missing_extension(error: &str) -> bool {
    ["UnknownMethod", "UnknownObject", "UnknownInterface"]
        .iter()
        .any(|name| error.contains(&format!("org.freedesktop.DBus.Error.{name}")))
}

/// Extracts the string of a `gdbus call` reply in the form of `('...',)`
fn parse_gvariant_string(output: &str) -> Result<String> {
    let inner = output
        .trim()
        .strip_prefix('(')
        .and_then(|s| s.strip_suffix(",)"))
        .context("unexpected gdbus reply")?;

    let mut chars = inner.chars();
    let quote = chars
        .next()
        .filter(|c| matches!(c, '\'' | '"'))
        .context("gdbus reply is not a string")?;

    let hex = |chars: &mut std::str::Chars, len: usize| -> Result<char> {
        let digits: String = chars.take(len).collect();
        u32::from_str_radix(&digits, 16)
            .ok()
            .and_then(char::from_u32)
            .context("invalid unicode escape in gdbus reply")
    };

    let mut result = String::new();

    loop {
        match chars.next().context("unterminated string in gdbus reply")? {
            c if c == quote => break,
            '\\' => {
                let c = match chars.next().context("unterminated escape in gdbus reply")? {
                    'a' => '\x07',
                    'b' => '\x08',
                    'f' => '\x0c',
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    'v' => '\x0b',
                    'u' => hex(&mut chars, 4)?,
                    'U' => hex(&mut chars, 8)?,
                    c => c,
                };

                result.push(c);
            }
            c => result.push(c),
        }
    }

    if !chars.as_str().is_empty() {
        bail!("unexpected trailing data in gdbus reply");
    }

    Ok(result)
}

#[derive(Deserialize)]
struct GnomeWindow {
    id: u64,
    title: Option<String>,
    wm_class: Option<String>,
    wm_class_instance: Option<String>,
}

fn parse_windows(output: &str) -> Result<Vec<Candidate>> {
    let windows: Vec<GnomeWindow> = serde_json::from_str(&parse_gvariant_string(output)?)?;

    Ok(windows
        .into_iter()
        .map(|w| Candidate {
            id: w.id.to_string(),
            classes: w.wm_class.into_iter().chain(w.wm_class_instance).collect(),
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
    fn parses_gvariant_strings() {
        assert_eq!(parse_gvariant_string("('[]',)\n").unwrap(), "[]");
        assert_eq!(
            parse_gvariant_string(r"('a\'b \\ \n \u00e9 \U0001f600 ü',)").unwrap(),
            "a'b \\ \n é 😀 ü"
        );
        assert_eq!(
            parse_gvariant_string(r#"("it's \"x\"",)"#).unwrap(),
            r#"it's "x""#
        );

        for invalid in ["", "('x')", "(x,)", "('x',)y", "('x,)", r"('\u12',)"] {
            assert!(parse_gvariant_string(invalid).is_err(), "{invalid}");
        }
    }

    #[test]
    fn reads_gnome_windows() {
        let output = r#"('[{"id":10,"title":"nvim","wm_class":"com.defold.nvim.p1","wm_class_instance":null},{"id":11,"title":"It\'s My Game","wm_class":"dmengine","wm_class_instance":"dmengine"},{"id":12,"title":"My Game","wm_class":null}]',)"#;

        let candidates = parse_windows(output).unwrap();
        assert_eq!(pick(&candidates, &neovim()), Some("10"));
        assert_eq!(pick(&candidates, &game()), Some("12"));
        assert_eq!(pick(&candidates, &titled("It's My Game")), Some("11"));
    }
}
