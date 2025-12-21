use anyhow::Context;
use defold_nvim_core::{bridge, editor, editor_config, mobdap, project};
use defold_nvim_core::{focus, game_project::GameProject};
use mlua::Value;
use mlua::prelude::*;
use std::path::PathBuf;
use std::{
    fs::{self},
    path::absolute,
    sync::OnceLock,
};
use tracing::instrument;
use tracing::level_filters::LevelFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::reload;
use tracing_subscriber::util::SubscriberInitExt;

static LOG_INIT: OnceLock<()> = OnceLock::new();
static LOG_RELOAD_HANDLE: OnceLock<reload::Handle<LevelFilter, tracing_subscriber::Registry>> =
    OnceLock::new();

#[mlua::lua_module]
fn defold_nvim_sidecar(lua: &Lua) -> LuaResult<LuaTable> {
    LOG_INIT.get_or_init(|| {
        let log_dir = dirs::cache_dir()
            .expect("could not get cache dir")
            .join("defold.nvim")
            .join("logs");

        fs::create_dir_all(&log_dir).expect("could not create logs dir");

        let (filter, handle) = reload::Layer::new(LevelFilter::INFO);
        LOG_RELOAD_HANDLE
            .set(handle)
            .expect("Logger handle already initialized");

        let file_layer = tracing_subscriber::fmt::layer()
            .with_ansi(false)
            .with_file(true)
            .with_line_number(true)
            .with_writer(tracing_appender::rolling::never(log_dir, "sidecar.log"));

        tracing_subscriber::registry()
            .with(filter)
            .with(file_layer)
            .init();

        std::panic::set_hook(Box::new(|panic_info| {
            let payload = panic_info.payload();
            let message = if let Some(s) = payload.downcast_ref::<&str>() {
                (*s).to_string()
            } else if let Some(s) = payload.downcast_ref::<String>() {
                s.clone()
            } else {
                "Unknown panic payload".to_string()
            };

            let location = panic_info.location().map_or_else(
                || "unknown location".to_string(),
                |l| format!("{}:{}:{}", l.file(), l.line(), l.column()),
            );

            tracing::error!(
                panic_message = %message,
                panic_location = %location,
                "SIDECAR PANIC"
            );
        }));
    });

    match register_exports(lua) {
        Ok(exports) => Ok(exports),
        Err(err) => {
            tracing::error!("Register Error: {lua:?}");
            Err(err)
        }
    }
}

fn register_exports(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set("version", lua.create_string(env!("CARGO_PKG_VERSION"))?)?;
    exports.set("set_log_level", lua.create_function(set_log_level)?)?;
    exports.set("read_game_project", lua.create_function(read_game_project)?)?;
    exports.set("find_editor_port", lua.create_function(find_editor_port)?)?;
    exports.set("is_editor_port", lua.create_function(is_editor_port)?)?;
    exports.set("list_commands", lua.create_function(list_commands)?)?;
    exports.set("send_command", lua.create_function(send_command)?)?;
    exports.set(
        "set_default_editor",
        lua.create_function(set_default_editor)?,
    )?;
    exports.set("find_bridge_path", lua.create_function(find_bridge_path)?)?;
    exports.set("focus_neovim", lua.create_function(focus_neovim)?)?;
    exports.set("focus_game", lua.create_function(focus_game)?)?;
    exports.set("mobdap_install", lua.create_function(mobdap_install)?)?;
    exports.set(
        "install_dependencies",
        lua.create_function(install_dependencies)?,
    )?;
    exports.set(
        "list_dependency_dirs",
        lua.create_function(list_dependency_dirs)?,
    )?;

    Ok(exports)
}

#[allow(clippy::needless_pass_by_value)]
#[instrument(level = "debug", err(Debug), skip_all)]
fn set_log_level(_lua: &Lua, level: String) -> LuaResult<()> {
    let new_filter = match level.to_lowercase().as_str() {
        "debug" => LevelFilter::DEBUG,
        "error" => LevelFilter::ERROR,
        _ => LevelFilter::INFO,
    };

    let handle = LOG_RELOAD_HANDLE
        .get()
        .context("could not get log handle")?;

    handle
        .modify(|f| *f = new_filter)
        .map_err(anyhow::Error::from)?;

    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn read_game_project(lua: &Lua, path: String) -> LuaResult<Value> {
    let game_project = GameProject::load_from_path(&absolute(path)?)?;
    let val = lua.to_value(&game_project)?;
    Ok(val)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn find_editor_port(_lua: &Lua, _: ()) -> LuaResult<u16> {
    let port = editor::find_port().context("could not find port")?;
    Ok(port)
}

#[allow(clippy::unnecessary_wraps)]
#[instrument(level = "debug", err(Debug), skip_all)]
fn is_editor_port(_lua: &Lua, port: u16) -> LuaResult<bool> {
    Ok(editor::is_editor_port(port))
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn list_commands(lua: &Lua, port: Option<u16>) -> LuaResult<LuaTable> {
    let commands = editor::list_commands(port)?;

    lua.create_table_from(commands)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn send_command(_lua: &Lua, (port, cmd): (Option<u16>, String)) -> LuaResult<()> {
    editor::send_command(port, &cmd)?;

    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn set_default_editor(
    lua: &Lua,
    (plugin_root, launcher_settings): (String, LuaValue),
) -> LuaResult<()> {
    let launcher_settings = lua.from_value(launcher_settings)?;
    editor_config::set_default_editor(&PathBuf::from(plugin_root), &launcher_settings)?;

    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn find_bridge_path(_lua: &Lua, plugin_root: String) -> LuaResult<String> {
    let path = bridge::path(&absolute(plugin_root)?)?;

    Ok(path
        .to_str()
        .context("could not convert path to string")?
        .to_string())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn focus_neovim(_lua: &Lua, game_root: String) -> LuaResult<()> {
    focus::focus_neovim(absolute(game_root)?)?;

    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn focus_game(_lua: &Lua, game_root: String) -> LuaResult<()> {
    focus::focus_game(absolute(game_root)?)?;

    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn mobdap_install(_lua: &Lua, _: ()) -> LuaResult<String> {
    let path = mobdap::update_or_install()?;
    Ok(path
        .to_str()
        .context("could not convert path to string")?
        .to_string())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn install_dependencies(
    _lua: &Lua,
    (game_root, force_redownload): (String, Option<bool>),
) -> LuaResult<()> {
    project::install_dependencies(&absolute(game_root)?, force_redownload.unwrap_or_default())?;
    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn list_dependency_dirs(_lua: &Lua, game_root: String) -> LuaResult<Vec<String>> {
    let deps = project::list_dependency_dirs(&absolute(game_root)?)?
        .into_iter()
        .map(|p| {
            p.to_str()
                .context("could not convert path to string")
                .unwrap()
                .to_string()
        })
        .collect();
    Ok(deps)
}
