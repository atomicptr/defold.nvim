use crate::{path, utils::project_id};
use anyhow::{Context, Result, bail};
use std::{
    fs,
    net::TcpListener,
    path::{Path, PathBuf},
};

#[derive(Debug, Clone, Copy)]
pub enum SocketType {
    Fsock,
    Netsock,
}

impl SocketType {
    pub fn parse(value: &str) -> Result<Self> {
        match value {
            "fsock" => Ok(Self::Fsock),
            "netsock" => Ok(Self::Netsock),
            _ => bail!("Invalid socket type '{value}', expected 'fsock' or 'netsock'"),
        }
    }
}

#[must_use]
pub fn default_socket_type() -> SocketType {
    if cfg!(target_os = "linux") || cfg!(target_os = "macos") {
        SocketType::Fsock
    } else {
        SocketType::Netsock
    }
}

pub fn runtime_dir(root_dir: &Path) -> Result<PathBuf> {
    let root_dir = root_dir
        .to_str()
        .context("could not convert root dir to string")?;

    let dir = path::cache_dir()?
        .join("runtime")
        .join(project_id(root_dir)?);

    fs::create_dir_all(&dir)?;
    Ok(dir)
}

pub fn fsock_path(root_dir: &Path) -> Result<PathBuf> {
    Ok(runtime_dir(root_dir)?.join("neovim.sock"))
}

pub fn netsock_port_file(root_dir: &Path) -> Result<PathBuf> {
    Ok(runtime_dir(root_dir)?.join("port"))
}

#[must_use]
pub fn find_free_port() -> Result<u16> {
    let listener = TcpListener::bind("127.0.0.1:0")?;
    let port = listener.local_addr()?.port();
    Ok(port)
}

pub fn read_or_allocate_netsock_port(root_dir: &Path) -> Result<u16> {
    let port_file = netsock_port_file(root_dir)?;

    if port_file.exists() {
        match fs::read_to_string(&port_file) {
            Ok(content) => {
                if let Ok(port) = content.trim().parse::<u16>() {
                    return Ok(port);
                }
            }
            Err(err) => {
                tracing::warn!(
                    "Could not read netsock port file '{}': {err}",
                    port_file.display()
                );
            }
        }
    }

    allocate_new_netsock_port(root_dir)
}

pub fn allocate_new_netsock_port(root_dir: &Path) -> Result<u16> {
    let port_file = netsock_port_file(root_dir)?;
    let port = find_free_port()?;
    fs::write(port_file, port.to_string())?;
    Ok(port)
}

pub fn allocate_new_netsock_addr(root_dir: &Path) -> Result<String> {
    let port = allocate_new_netsock_port(root_dir)?;
    Ok(format!("127.0.0.1:{port}"))
}

pub fn resolve_server_addr(root_dir: &Path, socket_type: Option<SocketType>) -> Result<String> {
    match socket_type.unwrap_or_else(default_socket_type) {
        SocketType::Fsock => Ok(fsock_path(root_dir)?
            .to_str()
            .context("could not convert socket file to string")?
            .to_string()),
        SocketType::Netsock => {
            let port = read_or_allocate_netsock_port(root_dir)?;
            Ok(format!("127.0.0.1:{port}"))
        }
    }
}
