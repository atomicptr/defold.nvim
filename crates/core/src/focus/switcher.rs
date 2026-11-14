use std::{env, path::Path, str::FromStr};

use anyhow::{Context, Result, bail};
use which::which;

use super::{
    Failure, Focus,
    command::run,
    switchers::{gdbus, hyprctl, kdotool, niri, osascript, swaymsg, wlrctl, wmctrl, xdotool},
    window::{Window, render},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Switcher {
    GDbus,
    HyprCtl,
    KDoTool,
    Niri,
    OsaScript,
    SwayMsg,
    WlrCtl,
    WmCtrl,
    XDoTool,
}

const SWITCHERS: [Switcher; 9] = [
    Switcher::GDbus,
    Switcher::HyprCtl,
    Switcher::KDoTool,
    Switcher::Niri,
    Switcher::OsaScript,
    Switcher::SwayMsg,
    Switcher::WlrCtl,
    Switcher::WmCtrl,
    Switcher::XDoTool,
];

impl Switcher {
    pub(super) fn name(self) -> &'static str {
        match self {
            Switcher::GDbus => "gdbus",
            Switcher::HyprCtl => "hyprctl",
            Switcher::KDoTool => "kdotool",
            Switcher::Niri => "niri",
            Switcher::OsaScript => "osascript",
            Switcher::SwayMsg => "swaymsg",
            Switcher::WlrCtl => "wlrctl",
            Switcher::WmCtrl => "wmctrl",
            Switcher::XDoTool => "xdotool",
        }
    }

    fn can_focus(self, window: &Window) -> bool {
        match self {
            Switcher::OsaScript => cfg!(target_os = "macos") && window.app.is_some(),
            _ => cfg!(target_os = "linux") && (window.class.is_some() || window.title.is_some()),
        }
    }

    fn focus(self, executable: &Path, window: &Window) -> Result<(), Failure> {
        match self {
            Switcher::GDbus => gdbus::focus(executable, window),
            Switcher::HyprCtl => hyprctl::focus(executable, window),
            Switcher::KDoTool => kdotool::focus(executable, window),
            Switcher::Niri => niri::focus(executable, window),
            Switcher::OsaScript => osascript::focus(executable, window),
            Switcher::SwayMsg => swaymsg::focus(executable, window),
            Switcher::WlrCtl => wlrctl::focus(executable, window),
            Switcher::WmCtrl => wmctrl::focus(executable, window),
            Switcher::XDoTool => xdotool::focus(executable, window),
        }
    }
}

impl FromStr for Switcher {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        SWITCHERS
            .into_iter()
            .find(|switcher| switcher.name() == value)
            .ok_or_else(|| {
                let names: Vec<_> = SWITCHERS.iter().map(|s| s.name()).collect();
                format!(
                    "Invalid focus type '{value}', expected one of: {}, 'auto' or 'custom'",
                    names.join(", ")
                )
            })
    }
}

/// Runs the first template the window has all placeholders for
pub fn focus_templates(
    executable: &Path,
    templates: &[&[&str]],
    window: &Window,
) -> Result<(), Failure> {
    let mut errors = Vec::new();

    for template in templates {
        let Ok(args) = render(template, window) else {
            continue;
        };

        match run(executable, &args, false) {
            Ok(_) => return Ok(()),
            Err(err) => errors.push(err.to_string()),
        }
    }

    Err(anyhow::anyhow!(errors.join("; ")).into())
}

fn detect() -> Vec<Switcher> {
    if cfg!(target_os = "macos") {
        vec![Switcher::OsaScript]
    } else if cfg!(target_os = "linux") {
        detect_linux(|name| env::var(name).ok())
    } else {
        Vec::new()
    }
}

fn detect_linux(var: impl Fn(&str) -> Option<String>) -> Vec<Switcher> {
    let has = |name| var(name).is_some_and(|value| !value.is_empty());
    let desktop = |name: &str| {
        var("XDG_CURRENT_DESKTOP")
            .is_some_and(|value| value.split(':').any(|d| d.eq_ignore_ascii_case(name)))
    };

    let mut switchers = Vec::new();

    if has("HYPRLAND_INSTANCE_SIGNATURE") {
        switchers.push(Switcher::HyprCtl);
    }

    if has("SWAYSOCK") {
        switchers.push(Switcher::SwayMsg);
    }

    if has("NIRI_SOCKET") {
        switchers.push(Switcher::Niri);
    }

    if desktop("KDE") {
        switchers.push(Switcher::KDoTool);
    }

    if desktop("GNOME") {
        switchers.push(Switcher::GDbus);
    }

    if has("WAYLAND_DISPLAY") {
        switchers.push(Switcher::WlrCtl);
    }

    // also covers XWayland windows
    if has("DISPLAY") {
        switchers.push(Switcher::WmCtrl);
        switchers.push(Switcher::XDoTool);
    }

    switchers
}

fn run_custom(executable: &str, arguments: &[String], window: &Window) -> Result<()> {
    let arguments = render(arguments, window).map_err(|name| {
        anyhow::anyhow!(
            "Focus arguments use {{{name}}}, which is not available for {} on this platform",
            window.subject.name()
        )
    })?;

    let path = which(executable)
        .with_context(|| format!("Could not find focus executable '{executable}'"))?;

    tracing::debug!("Running focus executable {} {arguments:?}", path.display());

    run(&path, &arguments, false)
        .with_context(|| format!("Focus executable '{executable}' failed"))?;

    Ok(())
}

pub fn switch(focus: &Focus, window: &Window) -> Result<()> {
    tracing::info!("Switching focus to {window:?}");

    let switchers = match focus {
        Focus::Off => return Ok(()),
        Focus::Custom {
            executable,
            arguments,
        } => return run_custom(executable, arguments, window),
        Focus::Switcher {
            switcher,
            executable,
        } => {
            if !switcher.can_focus(window) {
                tracing::debug!(
                    "{} can't focus {} on this platform",
                    switcher.name(),
                    window.subject.name()
                );
                return Ok(());
            }

            let name = executable.as_deref().unwrap_or(switcher.name());
            let executable =
                which(name).with_context(|| format!("Could not find focus switcher '{name}'"))?;

            return match switcher.focus(&executable, window) {
                Ok(()) => Ok(()),
                Err(Failure::Unavailable(reason)) => {
                    bail!("{} is not available: {reason}", switcher.name())
                }
                Err(Failure::Error(err)) => {
                    Err(err.context(format!("Could not switch focus using {}", switcher.name())))
                }
            };
        }
        Focus::Auto => detect(),
    };

    let switchers: Vec<_> = switchers
        .into_iter()
        .filter(|switcher| switcher.can_focus(window))
        .collect();

    // Neovim on macOS has no class, need something better
    if switchers.is_empty() {
        tracing::debug!(
            "No switcher can focus {} on this platform",
            window.subject.name()
        );
        return Ok(());
    }

    let mut errors = Vec::new();

    for switcher in switchers {
        let Ok(executable) = which(switcher.name()) else {
            continue;
        };

        match switcher.focus(&executable, window) {
            Ok(()) => return Ok(()),
            Err(Failure::Unavailable(reason)) => {
                tracing::debug!("{} is not available: {reason}", switcher.name());
            }
            Err(Failure::Error(err)) => errors.push(format!("{}: {err:#}", switcher.name())),
        }
    }

    if errors.is_empty() {
        tracing::warn!("No supported focus switcher found, do nothing...");
        return Ok(());
    }

    bail!("Could not switch focus: {}", errors.join("; "))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn detect_with(vars: &[(&str, &str)]) -> Vec<Switcher> {
        detect_linux(|name| {
            vars.iter()
                .find(|(key, _)| *key == name)
                .map(|(_, value)| (*value).to_string())
        })
    }

    #[test]
    fn ignores_missing_and_empty_session_variables() {
        assert_eq!(detect_with(&[]), Vec::<Switcher>::new());
        assert_eq!(
            detect_with(&[
                ("HYPRLAND_INSTANCE_SIGNATURE", ""),
                ("SWAYSOCK", ""),
                ("NIRI_SOCKET", ""),
                ("XDG_CURRENT_DESKTOP", ""),
                ("WAYLAND_DISPLAY", ""),
                ("DISPLAY", ""),
            ]),
            Vec::<Switcher>::new()
        );
    }

    #[test]
    fn detects_compositors_from_their_session_variables() {
        for (key, expected) in [
            ("HYPRLAND_INSTANCE_SIGNATURE", Switcher::HyprCtl),
            ("SWAYSOCK", Switcher::SwayMsg),
            ("NIRI_SOCKET", Switcher::Niri),
            ("WAYLAND_DISPLAY", Switcher::WlrCtl),
        ] {
            assert_eq!(detect_with(&[(key, "session")]), [expected], "{key}");
        }

        assert_eq!(
            detect_with(&[("DISPLAY", ":0")]),
            [Switcher::WmCtrl, Switcher::XDoTool]
        );
    }

    #[test]
    fn matches_complete_desktop_names_case_insensitively() {
        for (desktop, expected) in [
            ("ubuntu:gNoMe", Switcher::GDbus),
            ("kDe:other", Switcher::KDoTool),
        ] {
            assert_eq!(
                detect_with(&[("XDG_CURRENT_DESKTOP", desktop)]),
                [expected],
                "{desktop}"
            );
        }

        assert_eq!(
            detect_with(&[("XDG_CURRENT_DESKTOP", "NotGNOME:KDEish")]),
            Vec::<Switcher>::new()
        );
    }

    #[test]
    fn prefers_session_specific_switchers_before_generic_and_x11_fallbacks() {
        assert_eq!(
            detect_with(&[
                ("DISPLAY", ":0"),
                ("WAYLAND_DISPLAY", "wayland-1"),
                ("XDG_CURRENT_DESKTOP", "GNOME:KDE"),
                ("NIRI_SOCKET", "niri.sock"),
                ("SWAYSOCK", "sway.sock"),
                ("HYPRLAND_INSTANCE_SIGNATURE", "hyprland"),
            ]),
            [
                Switcher::HyprCtl,
                Switcher::SwayMsg,
                Switcher::Niri,
                Switcher::KDoTool,
                Switcher::GDbus,
                Switcher::WlrCtl,
                Switcher::WmCtrl,
                Switcher::XDoTool,
            ]
        );
    }
}
