use std::{fs, path::Path, time::Duration};

use anyhow::{Context, Result, bail};
use reqwest::blocking::Client;
use serde_json::Value;

use crate::editor_commands::CommandResult;

pub const PROBE_TIMEOUT: Duration = Duration::from_secs(1);

pub const REQUEST_TIMEOUT: Duration = Duration::from_secs(5);

pub const COMMAND_TIMEOUT: Duration = Duration::from_secs(120);

pub fn client(timeout: Duration) -> Result<Client> {
    Ok(Client::builder()
        .no_proxy()
        .redirect(reqwest::redirect::Policy::none())
        .connect_timeout(PROBE_TIMEOUT)
        .timeout(timeout)
        .build()?)
}

#[must_use]
pub fn editor_url(port: u16) -> String {
    format!("http://127.0.0.1:{port}")
}

fn parse_port(content: &str) -> Option<u16> {
    content.trim().parse().ok().filter(|port| *port != 0)
}

#[must_use]
pub fn find_port(game_root: &Path) -> Option<u16> {
    let content = fs::read_to_string(game_root.join(".internal").join("editor.port")).ok()?;
    let port = parse_port(&content)?;

    is_editor_port(port).then_some(port)
}

#[must_use]
pub fn is_editor_port(port: u16) -> bool {
    let result =
        client(PROBE_TIMEOUT).and_then(|client| Ok(client.head(editor_url(port)).send()?));

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
    let port = parse_port(&fs::read_to_string(internal.join("editor.port"))?)
        .context("invalid editor port")?;
    let token = fs::read_to_string(internal.join("editor.token"))?;
    query_version(port, token.trim())
}

fn query_version(port: u16, token: &str) -> Result<String> {
    let response = client(PROBE_TIMEOUT)?
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
    let res = client(REQUEST_TIMEOUT)?
        .get(format!("{}/openapi.json", editor_url(port)))
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
            .filter_map(|v| v.as_str().map(ToString::to_string))
            .collect();

        Ok(commands)
    } else {
        bail!("Could not find command values in the OpenAPI specification")
    }
}

pub fn send_command(port: u16, cmd: &str) -> Result<CommandResult> {
    let res = client(COMMAND_TIMEOUT)?
        .post(format!("{}/command/{cmd}", editor_url(port)))
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

#[must_use]
pub fn console_stream_url(port: u16) -> String {
    format!("{}/console/stream", editor_url(port))
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
