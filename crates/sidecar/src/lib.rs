use anyhow::Context;
use defold_nvim_core::{
    defold_gui, defold_inputs, defold_paths, editor, editor_config, engine, nvim_server, path,
    project, utils,
};
use defold_nvim_core::{focus, game_project::GameProject};
use mlua::Value::{self};
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
        let log_dir = path::cache_dir()
            .expect("could not get cache dir")
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

    exports.set("version", lua.create_string(utils::version())?)?;
    exports.set("set_log_level", lua.create_function(set_log_level)?)?;
    exports.set("read_game_project", lua.create_function(read_game_project)?)?;
    exports.set("is_editor_port", lua.create_function(is_editor_port)?)?;
    exports.set("list_commands", lua.create_function(list_commands)?)?;
    exports.set("send_command", lua.create_function(send_command)?)?;
    exports.set(
        "set_default_editor",
        lua.create_function(set_default_editor)?,
    )?;
    exports.set(
        "resolve_nvim_server_addr",
        lua.create_function(resolve_nvim_server_addr)?,
    )?;
    exports.set("focus_neovim", lua.create_function(focus_neovim)?)?;
    exports.set("focus_game", lua.create_function(focus_game)?)?;
    exports.set("unpack", lua.create_function(unpack)?)?;
    exports.set("move", lua.create_function(move_file)?)?;
    exports.set("hash", lua.create_function(hash)?)?;
    exports.set(
        "install_dependency",
        lua.create_function(install_dependency)?,
    )?;
    exports.set(
        "list_dependency_dirs",
        lua.create_function(list_dependency_dirs)?,
    )?;
    exports.set(
        "fetch_defold_paths_for",
        lua.create_function(fetch_defold_paths_for)?,
    )?;
    exports.set(
        "fetch_gui_nodes_for",
        lua.create_function(fetch_gui_nodes_for)?,
    )?;
    exports.set(
        "fetch_input_bindings",
        lua.create_function(fetch_input_bindings)?,
    )?;
    exports.set("editor_version", lua.create_function(editor_version)?)?;
    exports.set(
        "start_native_debugger",
        lua.create_function(start_native_debugger)?,
    )?;
    exports.set("project_id", lua.create_function(project_id)?)?;

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

#[allow(clippy::unnecessary_wraps)]
#[instrument(level = "debug", err(Debug), skip_all)]
fn is_editor_port(_lua: &Lua, port: u16) -> LuaResult<bool> {
    Ok(editor::is_editor_port(port))
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn list_commands(lua: &Lua, port: u16) -> LuaResult<LuaTable> {
    let commands = editor::list_commands(port)?;

    let table = lua.create_table()?;

    for (i, cmd) in commands.into_iter().enumerate() {
        table.set(i + 1, cmd)?;
    }

    Ok(table)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn send_command(lua: &Lua, (port, cmd): (u16, String)) -> LuaResult<Value> {
    let res = editor::send_command(port, &cmd)?;
    let val = lua.to_value(&res)?;

    Ok(val)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn set_default_editor(
    lua: &Lua,
    (port, bridge_path, launcher_settings, focus_settings): (u16, String, LuaValue, LuaValue),
) -> LuaResult<Option<String>> {
    let mut launcher_settings: editor_config::LauncherSettings = lua.from_value_with(
        launcher_settings,
        mlua::serde::DeserializeOptions::new().detect_mixed_tables(true),
    )?;

    let focus_error = match resolve_focus(lua, focus_settings, focus::Subject::Neovim) {
        Ok(focus) => {
            launcher_settings.focus = focus;
            None
        }
        Err(err) => Some(err.to_string()),
    };

    editor_config::set_default_editor(port, &PathBuf::from(bridge_path), &launcher_settings)?;

    Ok(focus_error)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn resolve_nvim_server_addr(
    _lua: &Lua,
    (game_root, socket_type): (String, Option<String>),
) -> LuaResult<String> {
    let root = absolute(game_root)?;
    let socket_type = socket_type
        .as_deref()
        .map(str::parse::<nvim_server::SocketType>)
        .transpose()
        .map_err(LuaError::external)?;

    let addr = nvim_server::resolve_server_addr(&root, socket_type)?;
    Ok(addr)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn focus_neovim(lua: &Lua, (game_root, settings): (String, LuaValue)) -> LuaResult<()> {
    let focus = resolve_focus(lua, settings, focus::Subject::Neovim)?;
    focus::focus_neovim(&absolute(game_root)?, &focus)?;

    Ok(())
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn focus_game(lua: &Lua, (game_root, settings): (String, LuaValue)) -> LuaResult<()> {
    let focus = resolve_focus(lua, settings, focus::Subject::Game)?;
    focus::focus_game(&absolute(game_root)?, &focus)?;

    Ok(())
}

fn resolve_focus(lua: &Lua, config: LuaValue, subject: focus::Subject) -> LuaResult<focus::Focus> {
    let config: focus::FocusConfig = if config.is_nil() {
        focus::FocusConfig::default()
    } else {
        lua.from_value(config)?
    };

    Ok(config.resolve(subject))
}

fn unpack(_lua: &Lua, (archive, target): (PathBuf, PathBuf)) -> LuaResult<()> {
    Ok(utils::unpack(&archive, &target)?)
}

fn move_file(_lua: &Lua, (source, target): (PathBuf, PathBuf)) -> LuaResult<()> {
    Ok(utils::move_file(&source, &target)?)
}

#[allow(clippy::unnecessary_wraps, clippy::needless_pass_by_value)]
fn hash(_lua: &Lua, input: String) -> LuaResult<String> {
    Ok(utils::sha3(&input))
}

fn install_dependency(_lua: &Lua, (source, target): (PathBuf, PathBuf)) -> LuaResult<Vec<String>> {
    Ok(project::install_dependency(&source, &target)?)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn editor_version(_lua: &Lua, game_root: String) -> LuaResult<String> {
    Ok(editor::version(&absolute(game_root)?)?)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn project_id(_lua: &Lua, game_root: String) -> LuaResult<String> {
    let game_root = absolute(game_root)?;
    Ok(utils::project_id(&game_root.display().to_string()))
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

#[instrument(level = "debug", err(Debug), skip_all)]
fn fetch_defold_paths_for(lua: &Lua, (root_dir, filepath): (PathBuf, PathBuf)) -> LuaResult<Value> {
    lua.to_value(&defold_paths::fetch_paths_for(&root_dir, &filepath)?)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn fetch_gui_nodes_for(lua: &Lua, (root_dir, filepath): (PathBuf, PathBuf)) -> LuaResult<Value> {
    lua.to_value(&defold_gui::fetch_nodes_for(&root_dir, &filepath)?)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn fetch_input_bindings(lua: &Lua, root_dir: PathBuf) -> LuaResult<Value> {
    lua.to_value(&defold_inputs::fetch_input_bindings(&root_dir)?)
}

#[instrument(level = "debug", err(Debug), skip_all)]
fn start_native_debugger(
    _lua: &Lua,
    (url, port, address): (String, u16, Option<String>),
) -> LuaResult<u16> {
    Ok(engine::start_native_debugger(
        &url,
        port,
        address.as_deref().unwrap_or("127.0.0.1"),
    )?)
}
