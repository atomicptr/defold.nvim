use crate::{path, utils::project_id};
use anyhow::{Context, Result};
use serde::Deserialize;
use std::{
    fs,
    net::TcpListener,
    path::{Path, PathBuf},
    str::FromStr,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SocketType {
    Fsock,
    Netsock,
}

impl FromStr for SocketType {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "fsock" => Ok(Self::Fsock),
            "netsock" => Ok(Self::Netsock),
            _ => Err(format!(
                "Invalid socket type '{value}', expected 'fsock' or 'netsock'"
            )),
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

fn runtime_dir(root_dir: &Path) -> Result<PathBuf> {
    let root_dir = root_dir
        .to_str()
        .context("could not convert root dir to string")?;

    let dir = path::cache_dir()?
        .join("runtime")
        .join(project_id(root_dir));

    fs::create_dir_all(&dir)?;
    Ok(dir)
}

fn fsock_path(root_dir: &Path) -> Result<PathBuf> {
    Ok(runtime_dir(root_dir)?.join("neovim.sock"))
}

fn netsock_port_file(root_dir: &Path) -> Result<PathBuf> {
    Ok(runtime_dir(root_dir)?.join("port"))
}

fn read_netsock_port(root_dir: &Path) -> Result<Option<u16>> {
    match fs::read_to_string(netsock_port_file(root_dir)?) {
        Ok(content) => Ok(content.trim().parse().ok()),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(err) => Err(err.into()),
    }
}

pub fn allocate_netsock_addr(root_dir: &Path) -> Result<String> {
    let port = TcpListener::bind("127.0.0.1:0")?.local_addr()?.port();
    fs::write(netsock_port_file(root_dir)?, port.to_string())?;
    Ok(netsock_addr(port))
}

fn netsock_addr(port: u16) -> String {
    format!("127.0.0.1:{port}")
}

pub fn resolve_server_addr(root_dir: &Path, socket_type: Option<SocketType>) -> Result<String> {
    match socket_type.unwrap_or_else(default_socket_type) {
        SocketType::Fsock => Ok(fsock_path(root_dir)?
            .to_str()
            .context("could not convert socket file to string")?
            .to_string()),
        SocketType::Netsock => match read_netsock_port(root_dir)? {
            Some(port) => Ok(netsock_addr(port)),
            None => allocate_netsock_addr(root_dir),
        },
    }
}
