use std::{
    io::{self, Read, Write},
    sync::mpsc::{RecvTimeoutError, channel},
    thread::sleep,
    time::{Duration, Instant},
};

use anyhow::{Context, Result};
use clap::ValueEnum;
use defold_nvim_core::{editor, editor_commands::Issue};
use sysinfo::System;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
pub enum Severity {
    #[value(name = "information", alias = "I")]
    Info,
    #[value(name = "warning", alias = "W")]
    Warning,
    #[value(name = "error", alias = "E")]
    Error,
}

pub fn build_game(port: u16, min_severity: Severity, enable_logs: bool) -> Result<()> {
    let mut sys =
        System::new().context("could not initialize process monitoring for game build")?;

    let before = find_running_dmengine_processes(&mut sys);

    let result = editor::send_command(port, "build")?;

    let issues: Vec<&Issue> = result
        .issues
        .iter()
        .filter(|i| {
            Severity::from_str(&i.severity, true).unwrap_or(Severity::Error) >= min_severity
        })
        .collect();

    // if we have issues, print them out and stop
    if !issues.is_empty() {
        for issue in issues {
            let Some(message) = issue_to_defold_error(issue) else {
                continue;
            };

            eprintln!("{message}");
        }

        return Ok(());
    }

    if !enable_logs {
        return Ok(());
    }

    let Ok(target_pid) = wait_for_dmengine(
        &mut sys,
        |pid| !before.contains(&pid),
        Duration::from_secs(15),
    ) else {
        anyhow::bail!("Could not find new Defold game instance")
    };

    tracing::debug!("Found dmengine pid {target_pid}");

    stream_logs(&mut sys, port, target_pid)
}

fn issue_to_defold_error(issue: &Issue) -> Option<String> {
    let severity = match issue.severity.to_lowercase().as_str() {
        "warning" => "WARNING",
        "info" => "INFO",
        _ => "ERROR",
    };

    let resource = issue.resource.as_deref()?;
    let path = resource.strip_prefix("/").unwrap_or(resource);
    let line = issue.range.as_ref().map_or(1, |r| r.start.line + 1);

    Some(format!(
        "{severity}:SCRIPT: {path}:{line}: {}",
        issue.message
    ))
}

fn find_running_dmengine_processes(sys: &mut System) -> Vec<u32> {
    sys.refresh_processes(sysinfo::ProcessesToUpdate::All, true);
    sys.processes()
        .values()
        .filter(|p| is_dmengine(p))
        .map(|p| p.pid().as_u32())
        .collect()
}

fn is_dmengine(p: &sysinfo::Process) -> bool {
    let name = p.name().to_string_lossy();

    if name == "dmengine" || name == "dmengine.exe" {
        return true;
    }

    if let Some(exe) = p.exe() {
        let s = exe.to_string_lossy();

        if s.contains("dmengine") {
            return true;
        }
    }

    false
}

fn wait_for_dmengine<AcceptFn>(
    sys: &mut System,
    accept_fn: AcceptFn,
    timeout: Duration,
) -> Result<u32>
where
    AcceptFn: Fn(u32) -> bool,
{
    let start = Instant::now();

    while start.elapsed() < timeout {
        if let Some(&pid) = find_running_dmengine_processes(sys)
            .iter()
            .find(|p| accept_fn(**p))
        {
            return Ok(pid);
        }

        sleep(Duration::from_millis(100));
    }

    anyhow::bail!("dmengine did not appear within {timeout:?}")
}

fn stream_logs(sys: &mut System, port: u16, game_pid: u32) -> Result<()> {
    let stream_url = editor::console_stream_url(port);

    let mut response = reqwest::blocking::Client::builder()
        .no_proxy()
        .build()?
        .get(&stream_url)
        .send()?
        .error_for_status()?;

    let (tx, rx) = channel::<Vec<u8>>();

    std::thread::spawn(move || {
        let mut buf = [0u8; 4096];

        loop {
            match response.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if tx.send(buf[..n].to_vec()).is_err() {
                        break;
                    }
                }
            }
        }
    });

    let mut stdout = io::stdout().lock();

    loop {
        if !process_alive(sys, game_pid) {
            while let Ok(chunk) = rx.try_recv() {
                let _ = stdout.write_all(&chunk);
            }

            let _ = stdout.flush();
            break;
        }

        match rx.recv_timeout(Duration::from_millis(200)) {
            Ok(chunk) => {
                stdout.write_all(&chunk)?;
                stdout.flush()?;
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }
    }

    Ok(())
}

fn process_alive(sys: &mut System, pid: u32) -> bool {
    let process = sysinfo::Pid::from_u32(pid);
    sys.refresh_processes(sysinfo::ProcessesToUpdate::Some(&[process]), true);
    sys.process(process).is_some()
}

#[cfg(test)]
mod tests {
    use super::issue_to_defold_error;
    use defold_nvim_core::editor_commands::{Issue, Position, Range};

    fn issue() -> Issue {
        Issue {
            message: "Undefined variable: player".to_owned(),
            severity: "error".to_owned(),
            resource: Some("/main/player.script".to_owned()),
            range: None,
        }
    }

    #[test]
    fn issues_without_resources_are_not_reported() {
        let mut issue = issue();
        issue.resource = None;

        assert_eq!(issue_to_defold_error(&issue), None);
    }

    #[test]
    fn resources_have_only_one_leading_forward_slash_removed() {
        for (resource, expected_path) in [
            ("/main/player.script", "main/player.script"),
            ("main/player.script", "main/player.script"),
            ("//main/player.script", "/main/player.script"),
            (r"\main\player.script", r"\main\player.script"),
            ("", ""),
        ] {
            let mut issue = issue();
            issue.resource = Some(resource.to_owned());

            assert_eq!(
                issue_to_defold_error(&issue),
                Some(format!(
                    "ERROR:SCRIPT: {expected_path}:1: Undefined variable: player"
                )),
                "resource: {resource:?}"
            );
        }
    }

    #[test]
    fn severity_is_case_insensitive_and_defaults_to_error() {
        for (severity, expected_severity) in [
            ("warning", "WARNING"),
            ("WaRnInG", "WARNING"),
            ("info", "INFO"),
            ("InFo", "INFO"),
            ("error", "ERROR"),
            ("ERROR", "ERROR"),
            ("unknown", "ERROR"),
            ("", "ERROR"),
        ] {
            let mut issue = issue();
            issue.severity = severity.to_owned();

            assert_eq!(
                issue_to_defold_error(&issue),
                Some(format!(
                    "{expected_severity}:SCRIPT: main/player.script:1: Undefined variable: player"
                )),
                "severity: {severity:?}"
            );
        }
    }

    #[test]
    fn range_start_line_is_converted_from_zero_based_to_one_based() {
        for (start_line, expected_line) in [(0, 1), (41, 42)] {
            let mut issue = issue();
            issue.range = Some(Range {
                start: Position {
                    line: start_line,
                    character: 12,
                },
                end: Position {
                    line: start_line + 3,
                    character: 24,
                },
            });

            assert_eq!(
                issue_to_defold_error(&issue),
                Some(format!(
                    "ERROR:SCRIPT: main/player.script:{expected_line}: Undefined variable: player"
                ))
            );
        }
    }

    #[test]
    fn missing_range_defaults_to_first_line() {
        let issue = issue();

        assert_eq!(
            issue_to_defold_error(&issue).as_deref(),
            Some("ERROR:SCRIPT: main/player.script:1: Undefined variable: player")
        );
    }
}
