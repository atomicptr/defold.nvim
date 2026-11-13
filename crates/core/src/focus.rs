use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{Context, Result, bail};
use which::which;

use crate::{game_project::GameProject, utils::classname};

#[derive(Debug, Clone, PartialEq, Eq)]
enum Target {
    Class(String),
    Title(String),
    AppName(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Switcher {
    HyprCtl,
    SwayMsg,
    WmCtrl,
    XDoTool,
    OsaScript,
}

impl Switcher {
    fn executable(self) -> &'static str {
        match self {
            Switcher::HyprCtl => "hyprctl",
            Switcher::SwayMsg => "swaymsg",
            Switcher::WmCtrl => "wmctrl",
            Switcher::XDoTool => "xdotool",
            Switcher::OsaScript => "osascript",
        }
    }
}

fn candidates() -> Vec<Switcher> {
    let has = |name| env::var_os(name).is_some_and(|value| !value.is_empty());

    let mut switchers = Vec::new();

    if cfg!(target_os = "macos") {
        switchers.push(Switcher::OsaScript);
    }

    if has("HYPRLAND_INSTANCE_SIGNATURE") {
        switchers.push(Switcher::HyprCtl);
    }

    if has("SWAYSOCK") {
        switchers.push(Switcher::SwayMsg);
    }

    // also covers XWayland windows
    if has("DISPLAY") {
        switchers.push(Switcher::WmCtrl);
        switchers.push(Switcher::XDoTool);
    }

    switchers
}

fn switch_args(switcher: Switcher, target: &Target) -> Option<Vec<String>> {
    let args = match (switcher, target) {
        (Switcher::HyprCtl, Target::Class(class)) => {
            vec![
                "dispatch".into(),
                format!(r#"hl.dsp.focus {{ window = "class:{class}" }}"#),
            ]
        }
        (Switcher::HyprCtl, Target::Title(title)) => {
            vec![
                "dispatch".into(),
                format!(r#"hl.dsp.focus {{ window = "title:{title}" }}"#),
            ]
        }
        (Switcher::SwayMsg, Target::Class(class)) => vec![format!("[class=\"{class}\"] focus")],
        (Switcher::SwayMsg, Target::Title(title)) => vec![format!("[title=\"{title}\"] focus")],
        (Switcher::WmCtrl, Target::Class(class)) => vec!["-x".into(), "-a".into(), class.clone()],
        (Switcher::WmCtrl, Target::Title(title)) => vec!["-a".into(), title.clone()],
        (Switcher::XDoTool, Target::Class(class)) => {
            vec![
                "search".into(),
                "--class".into(),
                class.clone(),
                "windowactivate".into(),
            ]
        }
        (Switcher::XDoTool, Target::Title(title)) => {
            vec![
                "search".into(),
                "--title".into(),
                title.clone(),
                "windowactivate".into(),
            ]
        }
        (Switcher::OsaScript, Target::AppName(app)) => vec![
            "-e".into(),
            format!(
                "tell application \"System Events\" to tell process {} to set frontmost to true",
                serde_json::to_string(app).ok()?
            ),
        ],
        _ => return None,
    };

    Some(args)
}

fn run(executable: &Path, switcher: Switcher, args: &[String]) -> Result<()> {
    let output = Command::new(executable).args(args).output()?;

    if !output.status.success() {
        bail!(
            "{} failed ({}): {}",
            switcher.executable(),
            output.status,
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }

    // hyprctl reports dispatch failures on stdout
    let stdout = String::from_utf8_lossy(&output.stdout);
    if switcher == Switcher::HyprCtl && stdout.trim() != "ok" {
        bail!("hyprctl failed: {}", stdout.trim());
    }

    Ok(())
}

fn switch(target: &Target) -> Result<()> {
    tracing::info!("Switching to {target:?}");

    let mut errors = Vec::new();

    for switcher in candidates() {
        let Some(args) = switch_args(switcher, target) else {
            continue;
        };

        let Ok(executable) = which(switcher.executable()) else {
            continue;
        };

        match run(&executable, switcher, &args) {
            Ok(()) => return Ok(()),
            Err(err) => errors.push(err.to_string()),
        }
    }

    if errors.is_empty() {
        tracing::warn!("No supported focus switcher found, do nothing...");
        return Ok(());
    }

    bail!("Could not switch focus: {}", errors.join("; "))
}

fn ensure_project(root_dir: &Path) -> Result<PathBuf> {
    let game_project = root_dir.join("game.project");

    if !game_project.exists() {
        bail!(
            "Could not find game.project file in {}: Not a valid Defold directory",
            root_dir.display()
        );
    }

    Ok(game_project)
}

pub fn focus_neovim(root_dir: &Path) -> Result<()> {
    ensure_project(root_dir)?;

    if !cfg!(target_os = "linux") {
        tracing::debug!("Focus switching to Neovim is not supported on the current platform");
        return Ok(());
    }

    let class = classname(
        root_dir
            .to_str()
            .context("could not convert path to string")?,
    );

    switch(&Target::Class(class))
}

pub fn focus_game(root_dir: &Path) -> Result<()> {
    let title = GameProject::load_from_path(&ensure_project(root_dir)?)?.title;

    if cfg!(target_os = "linux") {
        switch(&Target::Title(title))
    } else if cfg!(target_os = "macos") {
        switch(&Target::AppName(title))
    } else {
        tracing::debug!("Focus switching to the game is not supported on the current platform");
        Ok(())
    }
}
