use std::{fs, path::Path, time::Duration};

use anyhow::{Context, Result, bail};
use serde_json::Value;

use crate::editor_commands::CommandResult;

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
    let result = reqwest::blocking::Client::builder()
        .no_proxy()
        .build()
        .and_then(|client| client.head(editor_url(port)).send());

    match result {
        Ok(response) => {
            let status = response.status();

            if !status.is_success() {
                tracing::debug!(port, %status, "Defold Editor returned an unsuccessful status");
            }

            status.is_success()
        }
        Err(error) => {
            tracing::debug!(port, ?error, "Defold Editor request failed");
            false
        }
    }
}

pub fn version(game_root: &Path) -> Result<String> {
    let internal = game_root.join(".internal");
    let port = fs::read_to_string(internal.join("editor.port"))?;
    let token = fs::read_to_string(internal.join("editor.token"))?;
    query_version(port.trim().parse()?, token.trim())
}

fn query_version(port: u16, token: &str) -> Result<String> {
    let response = reqwest::blocking::Client::builder()
        .timeout(Duration::from_millis(500))
        .redirect(reqwest::redirect::Policy::none())
        .no_proxy()
        .build()?
        .post(format!("{}/eval", editor_url(port)))
        .bearer_auth(token)
        .header("Content-Type", "text/plain")
        .body("print(editor.version)")
        .send()?
        .error_for_status()?
        .text()?;

    Ok(parse_version(response.trim())?.to_owned())
}

pub(crate) fn parse_version(version: &str) -> Result<&str> {
    let parts: Vec<_> = version.split('.').collect();
    if parts.len() != 3
        || parts
            .iter()
            .any(|part| part.is_empty() || !part.bytes().all(|byte| byte.is_ascii_digit()))
    {
        bail!("invalid version {version}");
    }

    Ok(version)
}

pub fn list_commands(port: u16) -> Result<Vec<String>> {
    let url = openapi_url(port);

    let res = reqwest::blocking::Client::builder()
        .no_proxy()
        .build()?
        .get(url)
        .send()?;

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

pub fn send_command(port: u16, cmd: &str) -> Result<CommandResult> {
    let url = command_url(port, Some(cmd.to_string()));

    let res = reqwest::blocking::Client::builder()
        .no_proxy()
        .build()?
        .post(url)
        .send()?;
    let status = res.status().as_u16();

    let result = match res.json::<CommandResult>() {
        Ok(mut body) => {
            body.status = status;
            body
        }
        Err(_) => CommandResult {
            success: false,
            issues: vec![],
            status,
            target: None,
        },
    };

    Ok(result)
}

pub fn console_stream_url(port: u16) -> String {
    format!("http://localhost:{port}/console/stream")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_three_numeric_version_components() {
        for version in ["1.14.0", "0.0.0", "123.456.789"] {
            assert_eq!(parse_version(version).unwrap(), version);
        }
    }

    #[test]
    fn rejects_malformed_versions() {
        for version in [
            "",
            "1",
            "1.14",
            "1.14.0.1",
            ".14.0",
            "1..0",
            "1.14.",
            "1.14.1-beta",
            "v1.14.0",
            "1.14.a",
            "1.14.-1",
            "1.14.０",
            " 1.14.0",
            "1.14.0\n",
            "unexpected output",
        ] {
            assert!(parse_version(version).is_err(), "accepted {version:?}");
        }
    }
}
