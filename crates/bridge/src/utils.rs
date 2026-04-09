use netstat2::{AddressFamilyFlags, ProtocolFlags, get_sockets_info};

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
