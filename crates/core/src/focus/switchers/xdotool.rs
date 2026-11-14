use std::path::Path;

use crate::focus::{Failure, switcher::focus_templates, window::Window};

pub fn focus(executable: &Path, window: &Window) -> Result<(), Failure> {
    focus_templates(
        executable,
        &[
            &["search", "--class", "{CLASS}", "windowactivate"],
            &["search", "--title", "{TITLE}", "windowactivate"],
        ],
        window,
    )
}
