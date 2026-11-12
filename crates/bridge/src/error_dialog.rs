use std::path::Path;

use native_dialog::{DialogBuilder, MessageLevel};

pub fn show(error: &anyhow::Error, log_path: Option<&Path>) -> native_dialog::Result<()> {
    DialogBuilder::message()
        .set_level(MessageLevel::Error)
        .set_title("defold.nvim")
        .set_text(launch_error_message(error, log_path))
        .alert()
        .show()
}

fn launch_error_message(error: &anyhow::Error, log_path: Option<&Path>) -> String {
    let mut message = format!("Could not open Neovim.\n\n{error:#}");

    if let Some(log_path) = log_path {
        message.push_str(&format!("\n\nLog: {}", log_path.display()));
    }

    message
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_message_includes_chain_and_log_path() {
        let error = anyhow::anyhow!("executable not found").context("Could not start launcher");
        let message = launch_error_message(&error, Some(Path::new("bridge.log")));

        assert_eq!(
            message,
            "Could not open Neovim.\n\nCould not start launcher: executable not found\n\nLog: bridge.log"
        );
    }

    #[test]
    fn setup_error_message_does_not_claim_a_log_exists() {
        let error = anyhow::anyhow!("could not create logs");

        assert_eq!(
            launch_error_message(&error, None),
            "Could not open Neovim.\n\ncould not create logs"
        );
    }
}
