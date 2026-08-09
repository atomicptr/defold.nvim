use std::{
    io::{self, Read, Write},
    sync::mpsc::{RecvTimeoutError, channel},
    thread::sleep,
    time::{Duration, Instant},
};

use anyhow::Result;
use clap::ValueEnum;
use defold_nvim_core::{editor, editor_commands::Issue};
use sysinfo::System;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
pub enum Severity {
    #[value(name = "info", alias = "I")]
    Info,
    #[value(name = "warning", alias = "W")]
    Warning,
    #[value(name = "error", alias = "E")]
    Error,
}

pub fn build_game(port: u16, min_severity: Severity, enable_logs: bool) -> Result<()> {
    let mut sys = System::new();

    let before = find_running_dmengine_processes(&mut sys);

    let result = editor::send_command(port, "build")?;

    let issues: Vec<&Issue> = result
        .issues
        .iter()
        .filter(|i| {
            let severity =
                Severity::from_str(&i.severity, true).expect("severity must deserialize");

            severity >= min_severity
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

    let mut response = reqwest::blocking::get(&stream_url)?.error_for_status()?;

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
