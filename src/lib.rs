use anyhow::{Result, anyhow};
use nvim_oxi::conversion::ToObject;
use nvim_oxi::{Dictionary, Function, Object, ObjectKind};
use sha3::{Digest, Sha3_256};

use crate::game_project::GameProject;

mod editor;
mod error;
mod game_project;

use crate::error::*;

#[nvim_oxi::plugin]
fn defold_sidecar() -> Dictionary {
    Dictionary::from_iter([
        ("version", Object::from(env!("CARGO_PKG_VERSION"))),
        ("sha3", Object::from(Function::from_fn(sha3))),
        (
            "read_game_project",
            Object::from(Function::from_fn(read_game_project)),
        ),
        (
            "find_editor_port",
            Object::from(Function::from_fn(find_editor_port)),
        ),
        (
            "list_commands",
            Object::from(Function::from_fn(list_commands)),
        ),
        (
            "send_command",
            Object::from(Function::from_fn(send_command)),
        ),
    ])
}

fn sha3(input: Object) -> Object {
    if input.kind() != ObjectKind::String {
        return LuaError::from("sha3(input), expected input to be of type string".to_string())
            .to_object()
            .unwrap();
    };

    let input = unsafe { input.as_nvim_str_unchecked().to_string() };

    let mut hasher = Sha3_256::new();
    hasher.update(input.as_bytes());
    let result = hasher.finalize();

    format!("{:x}", result).into()
}

fn read_game_project(path: Object) -> Object {
    if path.kind() != ObjectKind::String {
        return LuaError::from(
            "read_game_project(path), expected path to be of type string".to_string(),
        )
        .to_object()
        .unwrap();
    };

    let path = unsafe { path.as_nvim_str_unchecked().to_string() };

    match GameProject::load_from_path(path.into()) {
        Ok(game_project) => game_project.to_object().unwrap_or_else(|err| {
            LuaError::from(anyhow::Error::from(err))
                .to_object()
                .unwrap()
        }),
        Err(err) => LuaError::from(err).to_object().unwrap(),
    }
}

fn find_editor_port(_: ()) -> Object {
    match editor::find_port() {
        Some(port) => Object::from(port),
        None => LuaError::from("Could not find editor port".to_string())
            .to_object()
            .unwrap(),
    }
}

fn list_commands(port: Object) -> Object {
    let port = match port.kind() {
        ObjectKind::Integer => match u16::try_from(unsafe { port.as_integer_unchecked() }) {
            Ok(port) => Some(port),
            Err(err) => {
                return LuaError::from(anyhow::Error::from(err))
                    .to_object()
                    .unwrap();
            }
        },
        _ => None,
    };

    let commands = editor::list_commands(port);

    let Ok(commands) = commands else {
        return LuaError::from(anyhow::Error::from(commands.unwrap_err()))
            .to_object()
            .unwrap();
    };

    Object::from_iter(commands)
}

fn send_command((port, cmd): (Object, Object)) -> Object {
    let Ok(port) = get_int_opt(port) else {
        return LuaError::from("send_command(port, cmd): port was not int|nil".to_string())
            .to_object()
            .unwrap();
    };

    let Ok(cmd) = get_string(cmd) else {
        return LuaError::from("send_command(port, cmd): cmd was not a string".to_string())
            .to_object()
            .unwrap();
    };

    if let Err(err) = editor::send_command(port, cmd) {
        return LuaError::from(err).to_object().unwrap();
    }

    Object::from(Dictionary::new())
}

fn get_int_opt<T: TryFrom<i64>>(o: Object) -> Result<Option<T>> {
    match o.kind() {
        ObjectKind::Integer => match T::try_from(unsafe { o.as_integer_unchecked() }) {
            Ok(v) => Ok(Some(v)),
            Err(_) => Ok(None),
        },
        ObjectKind::Nil => Ok(None),
        _ => Err(anyhow!("object was not an integer")),
    }
}

fn get_string(o: Object) -> Result<String> {
    match o.kind() {
        ObjectKind::String => String::try_from(unsafe { o.as_nvim_str_unchecked() }.to_string())
            .map_err(anyhow::Error::from),
        _ => Err(anyhow!("object was not a string")),
    }
}
