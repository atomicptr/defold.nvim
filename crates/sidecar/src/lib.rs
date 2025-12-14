use std::path::PathBuf;

use anyhow::Context;
use mlua::prelude::*;
use sha3::{Digest, Sha3_256};

use crate::game_project::GameProject;

mod editor;
mod editor_config;
mod game_project;

#[mlua::lua_module]
fn defold_nvim_sidecar(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set("version", lua.create_string(env!("CARGO_PKG_VERSION"))?)?;
    exports.set("sha3", lua.create_function(sha3)?)?;
    exports.set("read_game_project", lua.create_function(read_game_project)?)?;
    exports.set("find_editor_port", lua.create_function(find_editor_port)?)?;
    exports.set("list_commands", lua.create_function(list_commands)?)?;
    exports.set("send_command", lua.create_function(send_command)?)?;
    exports.set(
        "set_default_editor",
        lua.create_function(set_default_editor)?,
    )?;

    Ok(exports)
}

fn sha3(_lua: &Lua, str: String) -> LuaResult<String> {
    let mut hasher = Sha3_256::new();
    hasher.update(str.as_bytes());
    let result = hasher.finalize();

    Ok(format!("{:x}", result))
}

fn read_game_project(lua: &Lua, path: String) -> LuaResult<LuaAnyUserData> {
    let game_project = GameProject::load_from_path(path.into())?;
    lua.create_ser_userdata(game_project)
}

fn find_editor_port(_lua: &Lua, _: ()) -> LuaResult<u16> {
    let port = editor::find_port().context("could not find port")?;
    Ok(port)
}

fn list_commands(lua: &Lua, port: Option<u16>) -> LuaResult<LuaTable> {
    let commands = editor::list_commands(port)?;

    lua.create_table_from(commands)
}

fn send_command(_lua: &Lua, (port, cmd): (Option<u16>, String)) -> LuaResult<()> {
    editor::send_command(port, cmd)?;

    Ok(())
}

fn set_default_editor(_lua: &Lua, (plugin_root, launch_config): (String, String)) -> LuaResult<()> {
    editor_config::set_default_editor(PathBuf::from(plugin_root), PathBuf::from(launch_config))?;

    Ok(())
}
