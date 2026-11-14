use std::{
    ffi::OsStr,
    io::Read,
    process::{Child, Command, ExitStatus, Stdio},
    sync::mpsc,
    thread,
    time::{Duration, Instant},
};

use anyhow::{Result, bail};

const COMMAND_TIMEOUT: Duration = Duration::from_secs(3);

fn read_pipe(pipe: Option<impl Read + Send + 'static>) -> mpsc::Receiver<String> {
    let (sender, receiver) = mpsc::channel();

    if let Some(mut pipe) = pipe {
        thread::spawn(move || {
            let mut buffer = Vec::new();
            let _ = pipe.read_to_end(&mut buffer);
            let _ = sender.send(String::from_utf8_lossy(&buffer).into_owned());
        });
    }

    receiver
}

fn wait_with_timeout(child: &mut Child) -> Result<ExitStatus> {
    let deadline = Instant::now() + COMMAND_TIMEOUT;

    loop {
        if let Some(status) = child.try_wait()? {
            return Ok(status);
        }

        if Instant::now() >= deadline {
            child.kill()?;
            child.wait()?;
            bail!("timed out after {COMMAND_TIMEOUT:?}");
        }

        thread::sleep(Duration::from_millis(10));
    }
}

pub fn run(
    executable: impl AsRef<OsStr>,
    args: &[impl AsRef<OsStr>],
    capture: bool,
) -> Result<String> {
    let mut child = Command::new(executable)
        .args(args)
        .stdin(Stdio::null())
        .stdout(if capture {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stderr(Stdio::piped())
        .spawn()?;

    let stdout = read_pipe(child.stdout.take());
    let stderr = read_pipe(child.stderr.take());

    let status = wait_with_timeout(&mut child)?;

    let grace = Duration::from_millis(100);
    let stdout = stdout.recv_timeout(grace).unwrap_or_default();
    let stderr = stderr.recv_timeout(grace).unwrap_or_default();

    if !status.success() {
        bail!("exited with {status}: {}", stderr.trim());
    }

    Ok(stdout)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(unix)]
    #[test]
    fn runs_commands_without_waiting_for_background_processes() {
        let started = Instant::now();

        // the background sleep inherits the pipes, focus switching must not wait for it
        run("sh", &["-c", "sleep 5 & echo done"], true).unwrap();
        run("sh", &["-c", "sleep 5 & exit 0"], false).unwrap();

        assert!(started.elapsed() < Duration::from_secs(2));
    }

    #[cfg(unix)]
    #[test]
    fn kills_commands_after_the_timeout() {
        let started = Instant::now();

        let error = run("sleep", &["10"], false).unwrap_err();

        assert!(error.to_string().contains("timed out"), "{error}");
        assert!(started.elapsed() < COMMAND_TIMEOUT + Duration::from_secs(1));
    }
}
