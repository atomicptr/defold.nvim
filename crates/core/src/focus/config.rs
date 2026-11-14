use std::str::FromStr;

use anyhow::{Context, Result};
use serde::Deserialize;

use super::Switcher;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Subject {
    Neovim,
    Game,
}

impl Subject {
    pub(super) fn name(self) -> &'static str {
        match self {
            Subject::Neovim => "neovim",
            Subject::Game => "game",
        }
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum FocusType {
    #[default]
    Auto,
    Custom,
    Switcher(Switcher),
}

impl FromStr for FocusType {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "auto" => Ok(Self::Auto),
            "custom" => Ok(Self::Custom),
            "off" => Err("focus type 'off' is not supported, use 'enable = false' instead".into()),
            name => name.parse().map(Self::Switcher),
        }
    }
}

impl<'de> Deserialize<'de> for FocusType {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        String::deserialize(deserializer)?
            .parse()
            .map_err(serde::de::Error::custom)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct FocusConfig {
    pub enable: bool,
    #[serde(rename = "type")]
    pub focus_type: FocusType,
    pub executable: Option<String>,
    pub nvim_arguments: Option<Vec<String>>,
    pub game_arguments: Option<Vec<String>>,
}

impl Default for FocusConfig {
    fn default() -> Self {
        Self {
            enable: true,
            focus_type: FocusType::Auto,
            executable: None,
            nvim_arguments: None,
            game_arguments: None,
        }
    }
}

impl FocusConfig {
    #[must_use]
    pub fn resolve(&self, subject: Subject) -> Focus {
        if !self.enable {
            return Focus::Off;
        }

        let executable = self
            .executable
            .clone()
            .filter(|executable| !executable.is_empty());

        match self.focus_type {
            FocusType::Auto => Focus::Auto,
            FocusType::Switcher(switcher) => Focus::Switcher {
                switcher,
                executable,
            },
            FocusType::Custom => {
                let Some(executable) = executable else {
                    tracing::warn!("focus type 'custom' has no executable, falling back to 'auto'");
                    return Focus::Auto;
                };

                let arguments = match subject {
                    Subject::Neovim => &self.nvim_arguments,
                    Subject::Game => &self.game_arguments,
                };

                arguments
                    .as_ref()
                    .map_or(Focus::Off, |arguments| Focus::Custom {
                        executable,
                        arguments: arguments.clone(),
                    })
            }
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub enum Focus {
    #[default]
    Auto,
    Off,

    Switcher {
        switcher: Switcher,
        executable: Option<String>,
    },

    /// Placeholders are only applied to `arguments`
    Custom {
        executable: String,
        arguments: Vec<String>,
    },
}

impl Focus {
    /// `off` stands for `enable = false`, which isn't a config type
    #[must_use]
    pub fn cli_args(&self) -> Vec<String> {
        let mut args = Vec::new();

        let (focus_type, executable, arguments) = match self {
            Self::Auto => return args,
            Self::Off => ("off", None, &[][..]),
            Self::Switcher {
                switcher,
                executable,
            } => (switcher.name(), executable.as_ref(), &[][..]),
            Self::Custom {
                executable,
                arguments,
            } => ("custom", Some(executable), arguments.as_slice()),
        };

        args.extend(["--focus-type".to_string(), focus_type.to_string()]);

        if let Some(executable) = executable {
            args.extend(["--focus-executable".to_string(), executable.clone()]);
        }

        for argument in arguments {
            args.extend(["--focus-argument".to_string(), argument.clone()]);
        }

        args
    }

    pub fn from_cli(
        focus_type: Option<&str>,
        executable: Option<String>,
        arguments: Vec<String>,
    ) -> Result<Self> {
        let focus_type = match focus_type {
            None => FocusType::Auto,
            Some("off") => return Ok(Self::Off),
            Some(value) => value.parse().map_err(anyhow::Error::msg)?,
        };

        Ok(match focus_type {
            FocusType::Auto => Self::Auto,
            FocusType::Switcher(switcher) => Self::Switcher {
                switcher,
                executable,
            },
            FocusType::Custom => Self::Custom {
                executable: executable
                    .context("focus type 'custom' requires --focus-executable")?,
                arguments,
            },
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_focus_config() {
        let parse = |json: &str| serde_json::from_str::<FocusConfig>(json).unwrap();
        let resolve = |json: &str, subject| parse(json).resolve(subject);

        assert_eq!(resolve("{}", Subject::Neovim), Focus::Auto);
        assert_eq!(resolve(r#"{"type":"auto"}"#, Subject::Game), Focus::Auto);

        assert_eq!(
            resolve(
                r#"{"type":"hyprctl","executable":"/opt/hyprctl","game_arguments":[]}"#,
                Subject::Game
            ),
            Focus::Switcher {
                switcher: Switcher::HyprCtl,
                executable: Some("/opt/hyprctl".into())
            }
        );

        assert_eq!(
            resolve(r#"{"executable":"x","game_arguments":[]}"#, Subject::Game),
            Focus::Auto
        );

        let disabled = r#"{"enable":false,"type":"custom"}"#;
        assert_eq!(resolve(disabled, Subject::Neovim), Focus::Off);
        assert_eq!(resolve(disabled, Subject::Game), Focus::Off);

        let custom = r#"{"type":"custom","executable":"my-focus","nvim_arguments":["--class","{CLASS}"],"game_arguments":[]}"#;
        assert_eq!(
            resolve(custom, Subject::Neovim),
            Focus::Custom {
                executable: "my-focus".into(),
                arguments: vec!["--class".into(), "{CLASS}".into()]
            }
        );
        assert_eq!(
            resolve(custom, Subject::Game),
            Focus::Custom {
                executable: "my-focus".into(),
                arguments: vec![]
            }
        );

        let game_only = r#"{"type":"custom","executable":"my-focus","game_arguments":[]}"#;
        assert_eq!(resolve(game_only, Subject::Neovim), Focus::Off);

        for missing in [
            r#"{"type":"custom","nvim_arguments":[]}"#,
            r#"{"type":"custom","executable":"","nvim_arguments":[]}"#,
        ] {
            assert_eq!(resolve(missing, Subject::Neovim), Focus::Auto, "{missing}");
        }

        for invalid in [
            r#"{"type":"i3"}"#,
            r#"{"type":"off"}"#,
            r#"{"command":"x"}"#,
        ] {
            assert!(
                serde_json::from_str::<FocusConfig>(invalid).is_err(),
                "{invalid}"
            );
        }
    }
}
