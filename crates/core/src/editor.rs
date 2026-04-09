use std::{fs, path::Path};

use anyhow::{Context, Result, bail};
use serde_json::Value;

fn editor_url(port: u16) -> String {
    format!("http://127.0.0.1:{port}")
}

fn openapi_url(port: u16) -> String {
    format!("{}/openapi.json", editor_url(port))
}

fn command_url(port: u16, command: Option<String>) -> String {
    format!(
        "{}/command/{}",
        editor_url(port),
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
        .head(editor_url(port))
        .send()
        .is_ok_and(|r| r.status().is_success())
}

pub fn list_commands(port: u16) -> Result<Vec<String>> {
    let url = openapi_url(port);

    let res = reqwest::blocking::get(url)?;

    if !res.status().is_success() {
        bail!("could not list commands, status: {:?}", res.status());
    }

    let root: Value = res.json().context("Failed to parse OpenAPI JSON")?;

    let enum_values =
        &root["paths"]["/command/{command}"]["post"]["parameters"][0]["schema"]["enum"];

    if let Some(list) = enum_values.as_array() {
        let commands = list
            .iter()
            .filter_map(|v| v.as_str().map(|s| s.to_string()))
            .collect();

        Ok(commands)
    } else {
        bail!("Could not find command values in the OpenAPI specification")
    }
}

pub fn send_command(port: u16, cmd: &str) -> Result<()> {
    let url = command_url(port, Some(cmd.to_string()));

    let res = reqwest::blocking::Client::new().post(url).send()?;

    if !res.status().is_success() {
        bail!("could not send command {cmd}, status: {:?}", res.status());
    }

    Ok(())
}
