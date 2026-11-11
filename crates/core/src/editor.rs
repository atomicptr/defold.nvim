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
    reqwest::blocking::Client::new()
        .head(editor_url(port))
        .send()
        .is_ok_and(|r| r.status().is_success())
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

pub fn send_command(port: u16, cmd: &str) -> Result<CommandResult> {
    let url = command_url(port, Some(cmd.to_string()));

    let res = reqwest::blocking::Client::new().post(url).send()?;
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
    use std::{
        io::{Read, Write},
        net::TcpListener,
        thread,
    };

    fn eval_server(status: &str, body: &str) -> (u16, thread::JoinHandle<String>) {
        let server = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = server.local_addr().unwrap().port();
        let response = format!(
            "HTTP/1.1 {status}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
        let handle = thread::spawn(move || {
            let (mut stream, _) = server.accept().unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(2)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 1024];
            while !request.ends_with(b"print(editor.version)") {
                let n = stream.read(&mut buffer).unwrap();
                assert_ne!(n, 0);
                request.extend_from_slice(&buffer[..n]);
            }

            stream.write_all(response.as_bytes()).unwrap();
            String::from_utf8(request).unwrap()
        });
        (port, handle)
    }

    #[test]
    fn queries_editor_version_with_authentication() {
        let (port, server) = eval_server("200 OK", "1.14.0\n");
        assert_eq!(query_version(port, "test-token").unwrap(), "1.14.0");
        let request = server.join().unwrap();
        assert!(request.starts_with("POST /eval HTTP/1.1"));
        assert!(
            request
                .to_lowercase()
                .contains("authorization: bearer test-token")
        );
        assert!(request.to_lowercase().contains("content-type: text/plain"));
    }

    #[test]
    fn rejects_failed_or_unrecognized_version_queries() {
        for (status, body) in [
            ("401 Unauthorized", "Unauthorized"),
            ("404 Not Found", "Not Found"),
            ("503 Service Unavailable", "Not ready"),
            ("200 OK", "1.14.1-beta"),
            ("200 OK", "unexpected output"),
        ] {
            let (port, server) = eval_server(status, body);
            assert!(query_version(port, "test-token").is_err());
            server.join().unwrap();
        }
    }
}
