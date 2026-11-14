use std::path::Path;

use crate::focus::{Failure, switcher::focus_templates, window::Window};

pub fn focus(executable: &Path, window: &Window) -> Result<(), Failure> {
    focus_templates(
        executable,
        &[&[
            "-e",
            "on run argv",
            "-e",
            "tell application \"System Events\" to tell process (item 1 of argv) to set frontmost to true",
            "-e",
            "end run",
            "{APP}",
        ]],
        window,
    )
}
