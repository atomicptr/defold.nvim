mod candidate;
mod command;
mod config;
mod defold;
mod failure;
mod switcher;
mod switchers;
mod window;

pub use config::{Focus, FocusConfig, FocusType, Subject};
pub use defold::{focus_game, focus_neovim};
pub use switcher::Switcher;

use failure::Failure;
