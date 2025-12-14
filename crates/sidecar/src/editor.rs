use std::collections::HashMap;

use anyhow::{Context, Result, bail};
use netstat2::{AddressFamilyFlags, ProtocolFlags, ProtocolSocketInfo, iterate_sockets_info};
use sysinfo::System;

fn command_url(port: u16, command: Option<String>) -> String {
    format!(
        "http://127.0.0.1:{port}/command/{}",
        command.unwrap_or_default()
    )
}

pub fn find_port() -> Option<u16> {
    let sys = System::new_all();

    for (pid, proc) in sys.processes() {
        if !proc
            .name()
            .to_ascii_lowercase()
            .to_str()
            .unwrap_or_default()
            .contains("java")
        {
            continue;
        }

        let ports = ports_for_pid(pid.as_u32());

        if ports.is_err() {
            continue;
        }

        for port in ports.unwrap() {
            if is_editor(port) {
                return Some(port);
            }
        }
    }

    None
}

fn ports_for_pid(pid: u32) -> Result<Vec<u16>> {
    let mut ports = Vec::new();

    let af_flags = AddressFamilyFlags::IPV4 | AddressFamilyFlags::IPV6;
    let proto_flags = ProtocolFlags::TCP | ProtocolFlags::UDP;

    for socket in iterate_sockets_info(af_flags, proto_flags)? {
        let socket = socket?;

        if socket.associated_pids.contains(&pid) {
            match &socket.protocol_socket_info {
                ProtocolSocketInfo::Tcp(tcp) => {
                    ports.push(tcp.local_port);
                }
                ProtocolSocketInfo::Udp(udp) => {
                    ports.push(udp.local_port);
                }
            }
        }
    }

    Ok(ports)
}

fn is_editor(port: u16) -> bool {
    reqwest::blocking::Client::new()
        .head(command_url(port, None))
        .send()
        .is_ok_and(|r| r.status().is_success())
}

pub fn list_commands(port: Option<u16>) -> Result<HashMap<String, String>> {
    let url = command_url(
        port.or_else(|| find_port())
            .context("could not determine editor port")?,
        None,
    );

    let res = reqwest::blocking::get(url)?;

    if !res.status().is_success() {
        bail!("could not list commands, status: {:?}", res.status());
    }

    let content = res.text()?.to_string();

    serde_json::from_str(&content).map_err(|err| anyhow::Error::from(err))
}

pub fn send_command(port: Option<u16>, cmd: String) -> Result<()> {
    let url = command_url(
        port.or_else(|| find_port())
            .context("could not determine editor port")?,
        Some(cmd.clone()),
    );

    let res = reqwest::blocking::Client::new().post(url).send()?;

    if !res.status().is_success() {
        bail!("could not send command {cmd}, status: {:?}", res.status());
    }

    Ok(())
}
