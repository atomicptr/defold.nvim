use std::{fs, path::PathBuf};

use anyhow::{Result, bail};
use walkdir::{DirEntry, WalkDir};

use crate::{
    miniproto::{self, Message, Value},
    path,
};

pub fn fetch_input_bindings(root_dir: &PathBuf) -> Result<Vec<String>> {
    let bindings = WalkDir::new(root_dir)
        .into_iter()
        .filter_entry(|e| !path::is_hidden(e))
        .filter_map(Result::ok)
        .map(DirEntry::into_path)
        .filter(|p| p.is_file())
        .filter_map(|p| match p.extension() {
            Some(ext) if ext.to_string_lossy() == "input_binding" => Some(p),
            _ => None,
        })
        .collect::<Vec<_>>();

    let Some(binding_file) = bindings.first() else {
        bail!(
            "could not find .input_binding file in {}",
            root_dir.display()
        );
    };

    let data = fs::read_to_string(binding_file)?;

    let message = miniproto::parse(&data)?;

    Ok(parse_bindings(&message))
}

fn parse_bindings(message: &Message) -> Vec<String> {
    let mut bindings = Vec::new();

    for v in [
        "key_trigger",
        "mouse_trigger",
        "gamepad_trigger",
        "touch_trigger",
        "text_trigger",
    ]
    .into_iter()
    .flat_map(|key| message.get(key))
    {
        let Value::Message(value) = v else {
            continue;
        };

        let Some(action) = value
            .first_string("action")
            .filter(|action| !action.is_empty())
        else {
            continue;
        };

        bindings.push(action);
    }

    bindings.sort();
    bindings.dedup();

    bindings
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn collects_actions_from_all_trigger_types_without_duplicates() {
        let message = miniproto::parse(
            r#"
key_trigger { input: KEY_SPACE action: "interact" }
mouse_trigger { input: MOUSE_BUTTON_1 action: "click" }
gamepad_trigger { input: GAMEPAD_RPAD_DOWN action: "interact" }
gamepad_trigger { input: GAMEPAD_START action: "pause" }
touch_trigger { input: TOUCH_MULTI action: "touch" }
text_trigger { input: TEXT action: "text" }
key_trigger { input: KEY_A action: "" }
mouse_trigger { input: MOUSE_BUTTON_2 }
"#,
        )
        .unwrap();

        assert_eq!(
            parse_bindings(&message),
            ["click", "interact", "pause", "text", "touch"]
        );
    }
}
