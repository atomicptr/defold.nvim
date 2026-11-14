use std::path::Path;

use anyhow::{Result, bail};
use serde::Deserialize;

use crate::focus::{
    Failure,
    candidate::{Candidate, find},
    command::run,
    window::Window,
};

pub fn focus(executable: &Path, window: &Window) -> Result<(), Failure> {
    let clients = parse_windows(&run(executable, &["clients", "-j"], true)?)?;
    let output = run(executable, &focus_args(find(&clients, window)?)?, true)?;

    // hyprctl reports dispatch failures on stdout
    if output.trim() != "ok" {
        return Err(anyhow::anyhow!("{}", output.trim()).into());
    }

    Ok(())
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct HyprlandClient {
    address: String,
    class: Option<String>,
    initial_class: Option<String>,
    title: Option<String>,
}

fn parse_windows(output: &str) -> Result<Vec<Candidate>> {
    let clients: Vec<HyprlandClient> = serde_json::from_str(output)?;

    Ok(clients
        .into_iter()
        .map(|c| Candidate {
            id: c.address,
            classes: c.class.into_iter().chain(c.initial_class).collect(),
            title: c.title,
        })
        .collect())
}

// Use a validated address so window titles never enter the Lua expression
fn focus_args(address: &str) -> Result<Vec<String>> {
    let hex = address.strip_prefix("0x").unwrap_or_default();

    if hex.is_empty() || !hex.chars().all(|c| c.is_ascii_hexdigit()) {
        bail!("unexpected hyprland window address '{address}'");
    }

    Ok(vec![
        "dispatch".into(),
        format!(r#"hl.dsp.focus {{ window = "address:{address}" }}"#),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::candidate::pick;
    use crate::focus::window::test_windows::*;

    #[test]
    fn reads_hyprland_clients() {
        let clients = r#"[
            {"address":"0x1","mapped":true,"class":"","initialClass":"com.defold.nvim.p1","title":"nvim","pid":1},
            {"address":"0x2a","class":"dmengine","initialClass":"dmengine","title":"My Game"},
            {"address":"0x3","class":"x","title":"\"] exec rm -rf ~ ["}
        ]"#;

        let candidates = parse_windows(clients).unwrap();
        assert_eq!(pick(&candidates, &neovim()), Some("0x1"));
        assert_eq!(pick(&candidates, &game()), Some("0x2a"));

        assert_eq!(
            pick(&candidates, &titled(r#""] exec rm -rf ~ ["#)),
            Some("0x3")
        );
    }

    #[test]
    fn only_passes_validated_addresses_to_hyprctl() {
        assert_eq!(
            focus_args("0x2a").unwrap(),
            ["dispatch", r#"hl.dsp.focus { window = "address:0x2a" }"#]
        );

        for invalid in ["", "0x", "2a", "0x2a\" }", "0xzz"] {
            assert!(focus_args(invalid).is_err(), "{invalid}");
        }
    }
}
