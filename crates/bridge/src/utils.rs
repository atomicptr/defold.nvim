use netstat2::{AddressFamilyFlags, ProtocolFlags, get_sockets_info};
use sysinfo::System;

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

pub fn search_and_kill_process(search_string: &str) {
    let mut sys = System::new_all();
    sys.refresh_all();

    for (pid, process) in sys.processes() {
        let cmd_str = process
            .cmd()
            .iter()
            .map(|arg| arg.to_string_lossy())
            .collect::<Vec<_>>()
            .join(" ");

        if cmd_str.contains(search_string) {
            tracing::debug!("found process pid {}: {}", pid, cmd_str);

            if process.kill() {
                tracing::debug!("successfully killed pid {}", pid);
            }
        }
    }
}
