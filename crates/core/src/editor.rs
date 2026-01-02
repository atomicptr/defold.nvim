use std::{collections::HashMap, fs, path::Path};

use anyhow::{Result, bail};

fn command_url(port: u16, command: Option<String>) -> String {
    format!(
        "http://127.0.0.1:{port}/command/{}",
        command.unwrap_or_default()
    )
}

#[must_use]
pub fn find_port(game_root: &Path) -> Option<u16> {
    let editor_port = game_root.join(".internal").join("editor.port");

    // editor port file doesnt exist? Editor isn't open
    if !editor_port.exists() {
        return None;
    }

    let content = fs::read_to_string(editor_port).ok()?;

    let port: u16 = content.parse().ok()?;

    if is_editor_port(port) {
        Some(port)
    } else {
        None
    }
}

#[must_use]
pub fn is_editor_port(port: u16) -> bool {
    reqwest::blocking::Client::new()
        .head(command_url(port, None))
        .send()
        .is_ok_and(|r| r.status().is_success())
}

pub fn list_commands(port: u16) -> Result<HashMap<String, String>> {
    let url = command_url(port, None);

    let res = reqwest::blocking::get(url)?;

    if !res.status().is_success() {
        bail!("could not list commands, status: {:?}", res.status());
    }

    let content = res.text()?.clone();

    serde_json::from_str(&content).map_err(anyhow::Error::from)
}

pub fn send_command(port: u16, cmd: &str) -> Result<()> {
    let url = command_url(port, Some(cmd.to_string()));

    let res = reqwest::blocking::Client::new().post(url).send()?;

    if !res.status().is_success() {
        bail!("could not send command {cmd}, status: {:?}", res.status());
    }

    Ok(())
}
