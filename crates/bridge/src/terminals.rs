use std::{path::PathBuf, sync::LazyLock};

use which::which;

#[derive(Debug, Clone)]
pub enum RunArg {
    Arg(String),
    End,
}

#[derive(Debug, Clone)]
pub struct Terminal {
    pub executable: String,
    pub arguments: Vec<String>,
    pub class_arg: Option<String>,
    pub run_arg: Option<RunArg>,
}

impl Terminal {
    pub fn new(
        exe: &str,
        args: &Vec<&str>,
        class_arg: Option<&str>,
        run_arg: Option<RunArg>,
    ) -> Self {
        Terminal {
            executable: exe.to_string(),
            arguments: args.iter().map(std::string::ToString::to_string).collect(),
            class_arg: class_arg.map(std::string::ToString::to_string),
            run_arg,
        }
    }

    pub fn find_by_name(name: &str) -> Option<Terminal> {
        for term in LIST.iter() {
            if name == term.executable {
                return Some(term.clone());
            }
        }

        None
    }

    pub fn find_available() -> Option<Terminal> {
        for term in LIST.iter() {
            if which(&term.executable).is_ok() {
                return Some(term.clone());
            }
        }

        None
    }

    pub fn find_executable(&self) -> Option<PathBuf> {
        which(&self.executable).ok()
    }
}

pub static LIST: LazyLock<[Terminal; 6]> = LazyLock::new(|| {
    [
        Terminal::new(
            "alacritty",
            &Vec::new(),
            Some("--class="),
            Some(RunArg::Arg("-e".to_string())),
        ),
        Terminal::new(
            "foot",
            &Vec::new(),
            Some("--app-id="),
            Some(RunArg::Arg("-e".to_string())),
        ),
        Terminal::new(
            "ghostty",
            &Vec::new(),
            Some("--class="),
            Some(RunArg::Arg("-e".to_string())),
        ),
        Terminal::new(
            "kitty",
            &Vec::new(),
            Some("--class="),
            Some(RunArg::Arg("-e".to_string())),
        ),
        Terminal::new(
            "st",
            &Vec::new(),
            Some("-c="),
            Some(RunArg::Arg("-e".to_string())),
        ),
        Terminal::new(
            "wezterm",
            &vec!["start"],
            Some("--class"),
            Some(RunArg::End),
        ),
    ]
});
