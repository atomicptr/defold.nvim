use std::path::Path;

use anyhow::Result;
use serde::Serialize;

use crate::{
    game_project::GameProject,
    miniproto::{Message, Value},
    resources,
};

const DEFAULT_GAME_BINDING: &str = "/input/game.input_binding";

#[derive(Debug, Serialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct InputBinding {
    pub action: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub from_location: Option<String>,
}

fn game_binding_source(game_binding: Option<&str>) -> String {
    let binding = game_binding.unwrap_or(DEFAULT_GAME_BINDING);
    let binding = binding.strip_suffix('c').unwrap_or(binding);

    binding.trim_start_matches('/').to_string()
}

pub fn fetch_input_bindings(root_dir: &Path) -> Result<Vec<InputBinding>> {
    let project = GameProject::load_from_path(&root_dir.join("game.project"))?;
    let active = game_binding_source(project.game_binding.as_deref());

    let files = resources::load(root_dir, &["input_binding"]);

    if let Some(file) = files.iter().find(|file| file.path == active) {
        return Ok(collect_bindings(&file.message, None));
    }

    // the active file isn't part of the project (e.g. /builtins), so offer all of them
    let mut bindings: Vec<_> = files
        .iter()
        .flat_map(|file| collect_bindings(&file.message, Some(&format!("/{}", file.path))))
        .collect();

    bindings.sort();
    Ok(bindings)
}

fn collect_bindings(message: &Message, from_location: Option<&str>) -> Vec<InputBinding> {
    let mut actions = Vec::new();

    for value in [
        "key_trigger",
        "mouse_trigger",
        "gamepad_trigger",
        "touch_trigger",
        "text_trigger",
    ]
    .into_iter()
    .flat_map(|key| message.get(key))
    {
        let Value::Message(value) = value else {
            continue;
        };

        if let Some(action) = value
            .first_string("action")
            .filter(|action| !action.is_empty())
        {
            actions.push(action);
        }
    }

    actions.sort();
    actions.dedup();

    actions
        .into_iter()
        .map(|action| InputBinding {
            action,
            from_location: from_location.map(str::to_string),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::miniproto;

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

        let actions: Vec<_> = collect_bindings(&message, None)
            .into_iter()
            .map(|binding| binding.action)
            .collect();

        assert_eq!(actions, ["click", "interact", "pause", "text", "touch"]);
    }

    #[test]
    fn resolves_game_binding_source() {
        assert_eq!(game_binding_source(None), "input/game.input_binding");
        assert_eq!(
            game_binding_source(Some("/controls/main.input_bindingc")),
            "controls/main.input_binding"
        );
        assert_eq!(
            game_binding_source(Some("/builtins/input/all.input_bindingc")),
            "builtins/input/all.input_binding"
        );
    }
}
