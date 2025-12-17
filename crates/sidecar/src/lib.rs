use anyhow::Context;
use defold_nvim_core::{
    focus,
    game_project::GameProject,
    github,
    utils::{self},
};
use mlua::Value;
use mlua::prelude::*;
use std::{
    fs::{self, File},
    io,
    path::{PathBuf, absolute},
    sync::OnceLock,
};
use tracing::Level;
use tracing_appender::rolling::daily;

mod editor;
mod editor_config;

static LOG_INIT: OnceLock<()> = OnceLock::new();

#[mlua::lua_module]
fn defold_nvim_sidecar(lua: &Lua) -> LuaResult<LuaTable> {
    LOG_INIT.get_or_init(|| {
        let logs = dirs::cache_dir()
            .expect("could not get cache dir")
            .join("defold.nvim")
            .join("logs");

        fs::create_dir_all(&logs).expect("could not create logs dir");

        let rolling = daily(logs, "sidecar");

        tracing_subscriber::fmt()
            .with_ansi(false)
            .with_file(true)
            .with_line_number(true)
            .with_max_level(Level::DEBUG)
            .with_writer(rolling)
            .init();
    });

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
    exports.set("focus_neovim", lua.create_function(focus_neovim)?)?;
    exports.set("focus_game", lua.create_function(focus_game)?)?;
    exports.set("download", lua.create_function(download)?)?;
    exports.set(
        "fetch_github_release",
        lua.create_function(fetch_github_release)?,
    )?;

    Ok(exports)
}

fn sha3(_lua: &Lua, str: String) -> LuaResult<String> {
    Ok(utils::sha3(&str))
}

fn read_game_project(lua: &Lua, path: String) -> LuaResult<Value> {
    let game_project = GameProject::load_from_path(path.into())?;
    let val = lua.to_value(&game_project)?;
    Ok(val)
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

fn focus_neovim(_lua: &Lua, game_root: String) -> LuaResult<()> {
    focus::focus_neovim(absolute(game_root)?)?;

    Ok(())
}

fn focus_game(_lua: &Lua, game_root: String) -> LuaResult<()> {
    focus::focus_game(absolute(game_root)?)?;

    Ok(())
}

fn download(_lua: &Lua, (url, location): (String, String)) -> LuaResult<()> {
    let res = reqwest::blocking::get(url);
    if let Err(err) = res {
        return Err(anyhow::Error::from(err).into());
    }

    let mut res = res.unwrap();

    if let Err(err) = res.error_for_status_ref() {
        return Err(anyhow::Error::from(err).into());
    }

    let mut file = File::create(location)?;
    io::copy(&mut res, &mut file)?;

    Ok(())
}

fn fetch_github_release(lua: &Lua, (owner, repo): (String, String)) -> LuaResult<Value> {
    let res = github::fetch_release(&owner, &repo)?;
    let res = lua.to_value(&res)?;
    Ok(res)
}
