use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use std::process::Command;
use which::which;

use strum::IntoEnumIterator;

use crate::{game_project::GameProject, utils::classname};

#[derive(Debug)]
enum SwitcherType {
    Class(String),
    Title(String),
    AppName(String),
}

impl SwitcherType {
    fn value(&self) -> String {
        match self {
            SwitcherType::Class(c) => c.clone(),
            SwitcherType::Title(t) => t.clone(),
            SwitcherType::AppName(a) => a.clone(),
        }
    }
}

#[derive(Debug, strum::EnumIter)]
enum Switcher {
    #[cfg(target_os = "linux")]
    HyprCtl,

    #[cfg(target_os = "linux")]
    SwayMsg,

    #[cfg(target_os = "linux")]
    WmCtrl,

    #[cfg(target_os = "linux")]
    XDoTool,

    #[cfg(target_os = "macos")]
    OsaScript,
}

impl Switcher {
    fn path(&self) -> Option<PathBuf> {
        #[cfg(target_os = "linux")]
        match self {
            Switcher::HyprCtl => which("hyprctl").ok(),
            Switcher::SwayMsg => which("swaymsg").ok(),
            Switcher::WmCtrl => which("wmctrl").ok(),
            Switcher::XDoTool => which("xdotool").ok(),
        }
        #[cfg(target_os = "macos")]
        match self {
            Switcher::OsaScript => which("osascript").ok(),
        }
        #[cfg(target_os = "windows")]
        None
    }

    fn from_env() -> Option<Self> {
        Self::iter().find(|sw| sw.path().is_some())
    }
}

fn switch(switcher_type: SwitcherType) -> Result<()> {
    tracing::info!("Switching to {switcher_type:?}");

    let Some(switcher) = Switcher::from_env() else {
        tracing::error!("No supported focus switcher found, do nothing...");
        return Ok(());
    };

    #[cfg(target_os = "linux")]
    return match switcher {
        Switcher::HyprCtl => {
            Command::new(switcher.path().unwrap())
                .arg("dispatch")
                .arg("focuswindow")
                .arg(match switcher_type {
                    SwitcherType::Class(class) => format!("class:{class}"),
                    SwitcherType::Title(title) => format!("title:{title}"),
                    _ => bail!("Unsupported switcher type {switcher_type:?} for {switcher:?}"),
                })
                .spawn()?
                .wait()?;

            Ok(())
        }
        Switcher::SwayMsg => {
            Command::new(switcher.path().unwrap())
                .arg(format!(
                    "[{}={}] focus",
                    match switcher_type {
                        SwitcherType::Class(_) => format!("class"),
                        SwitcherType::Title(_) => format!("title"),
                        _ => bail!("Unsupported switcher type {switcher_type:?} for {switcher:?}"),
                    },
                    switcher_type.value(),
                ))
                .spawn()?
                .wait()?;

            Ok(())
        }
        Switcher::WmCtrl => {
            let mut cmd = Command::new(switcher.path().unwrap());

            if matches!(switcher_type, SwitcherType::Class(_)) {
                cmd.arg("-x");
            }

            cmd.arg("-a").arg(switcher_type.value()).spawn()?.wait()?;

            Ok(())
        }
        Switcher::XDoTool => {
            Command::new(switcher.path().unwrap())
                .arg("search")
                .arg(match switcher_type {
                    SwitcherType::Class(_) => format!("--class"),
                    SwitcherType::Title(_) => format!("--title"),
                    _ => bail!("Unsupported switcher type {switcher_type:?} for {switcher:?}"),
                })
                .arg(switcher_type.value())
                .arg("windowactivate")
                .spawn()?
                .wait()?;

            Ok(())
        }
    };

    #[cfg(target_os = "macos")]
    return match switcher {
        Switcher::OsaScript => {
            Command::new(switcher.path().unwrap())
                .arg("-e")
                .arg(match switcher_type {
                    SwitcherType::AppName(app_name) => format!("'tell application \"System Events\" to tell process \"{app_name}\" to set frontmost to true'"),
                    _ => bail!("Unsupported switcher type {switcher_type:?} for {switcher:?}"),
                })
                .spawn()?
                .wait()?;

            Ok(())
        }
    };

    #[cfg(target_os = "windows")]
    return Ok(());
}

pub fn focus_neovim(root_dir: PathBuf) -> Result<()> {
    if !root_dir.join("game.project").exists() {
        bail!("Could not find game.project file in {root_dir:?}: Not a valid Defold directory");
    }

    if cfg!(target_os = "linux") {
        let class = classname(
            root_dir
                .to_str()
                .context("could not convert path to string")?,
        )?;

        return switch(SwitcherType::Class(class));
    }

    tracing::error!("Focus switching to Neovim is not support on current platform");

    Ok(())
}

pub fn focus_game(root_dir: PathBuf) -> Result<()> {
    if !root_dir.join("game.project").exists() {
        bail!("Could not find game.project file in {root_dir:?}: Not a valid Defold directory");
    }

    let game_project = GameProject::load_from_path(root_dir.join("game.project"))?;

    if cfg!(target_os = "linux") {
        return switch(SwitcherType::Title(game_project.title));
    } else if cfg!(target_os = "macos") {
        return switch(SwitcherType::AppName(game_project.title));
    }

    tracing::error!("Focus switching to the Game is not support on current platform");

    Ok(())
}
