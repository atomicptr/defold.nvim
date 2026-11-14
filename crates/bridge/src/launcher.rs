use anyhow::{Context, Result, bail, ensure};
#[cfg(target_os = "linux")]
use defold_nvim_core::utils::classname;
use defold_nvim_core::{
    editor_config::{LauncherSettings, LauncherType},
    focus::focus_neovim,
    nvim_server::{self, SocketType},
    path,
};
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    thread,
    time::{Duration, Instant},
};
use termlauncher::{Application, CustomTerminal, Terminal};
use which::which;

const ERR_NEOVIDE_NOT_FOUND: &str = "Neovide is not installed. Make sure defold.nvim is setup properly or run the repair script. Or make sure the system executable is installed";
const ERR_TERMINAL_NOT_FOUND: &str = "Could not find any suitable terminal";

const VAR_CLASSNAME: &str = "{CLASSNAME}";
const VAR_ADDRESS: &str = "{ADDR}";

const REMOTE_TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Debug, PartialEq, Eq)]
enum Remote {
    Ok(String),
    Unreachable,
    Failed(String),
}

fn classify_remote(success: bool, stdout: &str, stderr: &str) -> Remote {
    if success {
        Remote::Ok(stdout.trim().to_string())
    } else if stderr.contains("E247:") {
        Remote::Unreachable
    } else {
        Remote::Failed(stderr.trim().to_string())
    }
}

fn remote_expr(nvim: &str, server: &str, expr: &str) -> Result<Remote> {
    let mut child = Command::new(nvim)
        .args(["--headless", "--server", server, "--remote-expr", expr])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    let deadline = Instant::now() + REMOTE_TIMEOUT;

    while child.try_wait()?.is_none() {
        if Instant::now() >= deadline {
            child.kill()?;
            child.wait()?;
            return Ok(Remote::Failed(format!(
                "timed out after {REMOTE_TIMEOUT:?}"
            )));
        }

        thread::sleep(Duration::from_millis(20));
    }

    let output = child.wait_with_output()?;

    Ok(classify_remote(
        output.status.success(),
        &String::from_utf8_lossy(&output.stdout),
        &String::from_utf8_lossy(&output.stderr),
    ))
}

// Deferred with a timer so we don't block the remote call
fn open_file_expr(file: &str, line: Option<usize>) -> String {
    let line = line.map(|line| format!("+{line} ")).unwrap_or_default();
    let file = file.replace('\'', "''");

    format!("timer_start(0, {{-> execute('drop {line}' .. fnameescape('{file}'))}})")
}

// Gives a starting/reconnecting frontend a second chance
fn attached_uis(nvim: &str, server: &str) -> Result<Remote> {
    let remote = remote_expr(nvim, server, "len(nvim_list_uis())")?;

    if remote == Remote::Ok("0".to_string()) {
        thread::sleep(Duration::from_millis(300));
        return remote_expr(nvim, server, "len(nvim_list_uis())");
    }

    Ok(remote)
}

fn quit_headless(nvim: &str, server: &str) -> Result<()> {
    remote_expr(nvim, server, "execute('qall!')")?;

    for _ in 0..20 {
        if remote_expr(nvim, server, "1")? == Remote::Unreachable {
            return Ok(());
        }

        thread::sleep(Duration::from_millis(100));
    }

    bail!(
        "Neovim at {server} has no window attached and could not be closed. Reattach with `nvim --server {server} --remote-ui` or close it."
    )
}

fn check_launch(mut child: Child) -> Result<()> {
    let deadline = Instant::now() + Duration::from_millis(500);

    while Instant::now() < deadline {
        if let Some(status) = child.try_wait()? {
            ensure!(status.success(), "Launcher exited with {status}");
            return Ok(());
        }

        thread::sleep(Duration::from_millis(50));
    }

    tracing::debug!("Launcher still running, detaching...");
    Ok(())
}

fn nvim_args(file: &str, line: Option<usize>) -> Vec<String> {
    let mut args = vec!["--listen".to_string(), VAR_ADDRESS.to_string()];

    if let Some(line) = line {
        args.push(format!("+{line}"));
    }

    args.push(file.to_string());
    args
}

fn apply_vars(args: &[String], var: &str, replace_with: &str) -> Vec<String> {
    args.iter().map(|s| s.replace(var, replace_with)).collect()
}

fn managed_neovide() -> Option<PathBuf> {
    let bin = path::data_dir().ok()?.join("bin");

    let managed = if cfg!(target_os = "macos") {
        bin.join("Neovide.app/Contents/MacOS/neovide")
    } else if cfg!(target_os = "windows") {
        bin.join("neovide.exe")
    } else {
        bin.join("neovide")
    };

    managed.is_file().then_some(managed)
}

fn create_launcher(cfg: &LauncherSettings) -> Result<(Terminal, LauncherType)> {
    match cfg.launcher_type {
        Some(LauncherType::Neovide) => {
            let executable = cfg
                .executable
                .as_ref()
                .map(PathBuf::from)
                .or_else(|| which("neovide").ok())
                .or_else(managed_neovide)
                .filter(|executable| executable.exists())
                .context(ERR_NEOVIDE_NOT_FOUND)?;

            let mut args = cfg.arguments.clone().unwrap_or_default();

            if cfg!(target_os = "linux") {
                args.push("--wayland_app_id".to_string());
                args.push(VAR_CLASSNAME.to_string());

                args.push("--x11-wm-class".to_string());
                args.push(VAR_CLASSNAME.to_string());
            }

            Ok((
                Terminal::Custom(CustomTerminal {
                    executable: executable
                        .to_str()
                        .context("could not convert path to string")?
                        .to_string(),
                    arguments: args,
                    run_arg: Some("--neovim-bin".to_string()),
                    ..Default::default()
                }),
                LauncherType::Neovide,
            ))
        }
        Some(LauncherType::Terminal) => {
            // terminal specified by absolute path
            if let Some(executable) = &cfg.executable
                && Path::new(executable).is_absolute()
                && Path::new(executable).exists()
            {
                return Ok((
                    Terminal::Custom(CustomTerminal {
                        executable: executable.clone(),
                        arguments: cfg.arguments.clone().unwrap_or_default(),
                        ..Default::default()
                    }),
                    LauncherType::Terminal,
                ));
            }

            // `arguments`/`run_arg` only apply to custom terminals
            if let Some(name) = &cfg.executable
                && let Some(term) = Terminal::find_by_name(name)
                && term.is_available()
            {
                return Ok((term, LauncherType::Terminal));
            }

            Terminal::find_available()
                .map(|term| (term, LauncherType::Terminal))
                .context(ERR_TERMINAL_NOT_FOUND)
        }
        None => create_launcher(&LauncherSettings {
            launcher_type: Some(LauncherType::Neovide),
            ..cfg.clone()
        })
        .or_else(|_| {
            create_launcher(&LauncherSettings {
                launcher_type: Some(LauncherType::Terminal),
                ..cfg.clone()
            })
        })
        .context("Could neither find Neovide nor any supported terminal"),
    }
}

fn launch(launcher: &Terminal, mut app: Application, addr: &str) -> Result<()> {
    tracing::debug!("Launching new Neovim instance at {addr}");

    app.args = apply_vars(&app.args, VAR_ADDRESS, addr);

    let launcher = match launcher {
        Terminal::Custom(term) => Terminal::Custom(CustomTerminal {
            arguments: apply_vars(&term.arguments, VAR_ADDRESS, addr),
            ..term.clone()
        }),
        term => term.clone(),
    };

    check_launch(app.launch_with(&launcher)?)
}

pub fn run(
    settings: &LauncherSettings,
    root_dir: &Path,
    file: &Path,
    line: Option<usize>,
) -> Result<()> {
    let nvim = which("nvim")?
        .to_str()
        .context("could not convert nvim path to string")?
        .to_string();

    let file = file.to_str().context("could not convert path to string")?;

    let socket_type = settings
        .socket_type
        .unwrap_or_else(nvim_server::default_socket_type);

    let addr = nvim_server::resolve_server_addr(root_dir, Some(socket_type))?;

    let (launcher, launcher_type) = create_launcher(settings)?;
    let mut launcher = match launcher {
        Terminal::Custom(mut term) => {
            term.run_arg = settings.run_arg.clone().or(term.run_arg);
            Terminal::Custom(term)
        }
        term => term,
    };

    let mut app = Application::new(&nvim).with_working_dir(root_dir);
    app.args = nvim_args(file, line);

    #[cfg(target_os = "linux")]
    {
        let class = classname(
            root_dir
                .to_str()
                .context("could not convert path to string")?,
        );

        app = app.with_class(&class);

        // replace the class placeholder in custom launcher arguments too
        if let Terminal::Custom(term) = &mut launcher {
            term.arguments = apply_vars(&term.arguments, VAR_CLASSNAME, &class);
        }
    }

    // Neovide passes everything after "--" to Neovim
    if launcher_type == LauncherType::Neovide {
        app.args.insert(0, "--".to_string());
    }

    if let Some(appname) = &settings.appname {
        app.env_vars
            .insert("NVIM_APPNAME".to_string(), appname.clone());
    }

    match attached_uis(&nvim, &addr)? {
        Remote::Unreachable => {
            if socket_type == SocketType::Fsock {
                match fs::remove_file(&addr) {
                    Err(err) if err.kind() != std::io::ErrorKind::NotFound => {
                        return Err(err.into());
                    }
                    _ => {}
                }
            }

            launch(&launcher, app, &addr)?;
        }
        Remote::Ok(uis) if uis == "0" => {
            quit_headless(&nvim, &addr)?;
            launch(&launcher, app, &addr)?;
        }
        Remote::Ok(_) => match remote_expr(&nvim, &addr, &open_file_expr(file, line))? {
            Remote::Ok(_) => {}
            Remote::Unreachable => launch(&launcher, app, &addr)?,
            Remote::Failed(err) => bail!("Could not open {file} in Neovim at {addr}: {err}"),
        },
        Remote::Failed(err) if socket_type == SocketType::Netsock => {
            tracing::warn!("{addr} is not a usable Neovim server: {err}");
            launch(
                &launcher,
                app,
                &nvim_server::allocate_netsock_addr(root_dir)?,
            )?;
        }
        Remote::Failed(err) => bail!("Neovim at {addr} is not responding: {err}"),
    }

    if let Err(err) = focus_neovim(root_dir, &settings.focus) {
        tracing::error!("Could not switch focus to neovim {err:?}");
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_remote_results() {
        assert_eq!(classify_remote(true, "2\n", ""), Remote::Ok("2".into()));
        assert_eq!(
            classify_remote(
                false,
                "",
                "E247: Failed to connect to '/tmp/x': connection refused. Send expression failed."
            ),
            Remote::Unreachable
        );
        assert_eq!(
            classify_remote(
                false,
                "",
                "Lua: Vim(qall):E37: No write since last change\n"
            ),
            Remote::Failed("Lua: Vim(qall):E37: No write since last change".into())
        );
    }

    #[test]
    fn nvim_args_keep_file_before_appended_launcher_flags() {
        let file = r"C:\Users\Docker\My Project\main\testa.script";

        assert_eq!(
            nvim_args(file, Some(12)),
            ["--listen", VAR_ADDRESS, "+12", file]
        );

        assert_eq!(nvim_args(file, None), ["--listen", VAR_ADDRESS, file]);
    }

    #[test]
    fn open_file_expr_escapes_filename_as_literal_string() {
        assert_eq!(
            open_file_expr("/a b/it's|x.lua", Some(12)),
            "timer_start(0, {-> execute('drop +12 ' .. fnameescape('/a b/it''s|x.lua'))})"
        );
    }
}
