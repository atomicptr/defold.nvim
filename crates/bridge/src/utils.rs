use std::{fs, net::TcpListener, path::PathBuf};

use anyhow::{Context, Result};
use defold_nvim_core::utils::project_id;
use netstat2::{AddressFamilyFlags, ProtocolFlags, get_sockets_info};

pub fn runtime_dir(root_dir: &str) -> Result<PathBuf> {
    let dir = dirs::cache_dir()
        .context("could not get cache dir")?
        .join("defold.nvim")
        .join("runtime")
        .join(project_id(root_dir)?);
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

pub fn is_port_in_use(port: u16) -> bool {
    let af_flags = AddressFamilyFlags::IPV4 | AddressFamilyFlags::IPV6;
    let proto_flags = ProtocolFlags::TCP | ProtocolFlags::UDP;
    if let Ok(sockets) = get_sockets_info(af_flags, proto_flags) {
        for socket in sockets {
            match socket.protocol_socket_info {
                netstat2::ProtocolSocketInfo::Tcp(tcp) => {
                    if tcp.local_port == port {
                        return true;
                    }
                }
                netstat2::ProtocolSocketInfo::Udp(udp) => {
                    if udp.local_port == port {
                        return true;
                    }
                }
            }
        }
    }
    false
}

pub fn find_free_port() -> u16 {
    TcpListener::bind("127.0.0.1:0")
        .expect("Failed to bind")
        .local_addr()
        .expect("Failed to get local addr")
        .port()
}
