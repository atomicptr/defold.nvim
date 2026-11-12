use std::{
    io::Read,
    net::TcpListener,
    thread,
    time::{Duration, Instant},
};

use anyhow::{Context, Result, ensure};
use reqwest::{Url, blocking::Client, redirect::Policy};

pub fn start_native_debugger(url: &str, port: u16, address: &str) -> Result<u16> {
    let base = Url::parse(url).context("invalid engine service URL")?;

    let port = if port == 0 {
        TcpListener::bind(("127.0.0.1", 0))
            .context("could not allocate a debugger port")?
            .local_addr()?
            .port()
    } else {
        port
    };

    let client = Client::builder()
        .no_proxy()
        .redirect(Policy::none())
        .retry(reqwest::retry::never())
        .build()?;

    wait_for_engine(&client, base.join("ping")?)?;

    let payload = debugger_payload(port, address)?;

    ensure!(
        payload.len() <= 1024,
        "debugger activation payload exceeds 1024 bytes"
    );

    let response = client
        .post(base.join("post/@system/run_script")?)
        .timeout(Duration::from_secs(2))
        .header("Content-Type", "application/octet-stream")
        .body(payload)
        .send()
        .context("failed to request native debugger activation")?;

    ensure!(
        response.status().is_success(),
        "engine rejected debugger activation: {}",
        response.status()
    );

    Ok(port)
}

fn wait_for_engine(client: &Client, ping_url: Url) -> Result<()> {
    let deadline = Instant::now() + Duration::from_secs(5);

    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        ensure!(
            !remaining.is_zero(),
            "engine readiness timed out after 5 seconds"
        );

        let error = match ping(
            client,
            ping_url.clone(),
            remaining.min(Duration::from_millis(500)),
        ) {
            Ok(()) => return Ok(()),
            Err(error) => error,
        };

        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(error).context("engine readiness timed out after 5 seconds");
        }

        thread::sleep(remaining.min(Duration::from_millis(100)));
    }
}

fn ping(client: &Client, url: Url, timeout: Duration) -> Result<()> {
    let response = client.get(url).timeout(timeout).send()?;
    ensure!(
        response.status().is_success(),
        "engine ping returned {}",
        response.status()
    );

    let mut body = Vec::new();
    response.take(16).read_to_end(&mut body)?;
    ensure!(
        body == b"PONG" || body == b"PONG\n",
        "engine ping did not return PONG"
    );

    Ok(())
}

fn debugger_payload(port: u16, address: &str) -> Result<Vec<u8>> {
    let address = serde_json::to_string(address)?;
    let script = format!(
        r#"local port = debugger.start({port}, {address})
assert(port == {port}, "defold.nvim: debugger already listening on a different port, please restart the game")"#
    );

    Ok(encode_run_script(script.as_bytes()))
}

fn encode_run_script(script: &[u8]) -> Vec<u8> {
    let mut source = Vec::new();
    encode_bytes_field(&mut source, 1, script);
    encode_bytes_field(&mut source, 2, b"@defold.nvim/debugger.lua");

    let mut module = Vec::new();
    encode_bytes_field(&mut module, 1, &source);

    let mut message = Vec::new();
    encode_bytes_field(&mut message, 1, &module);
    message
}

fn encode_bytes_field(output: &mut Vec<u8>, field_number: u8, bytes: &[u8]) {
    // Protobuf keys combine the field number and wire type (2 = length-delimited).
    output.push((field_number << 3) | 2);

    let mut length = bytes.len();
    while length >= 128 {
        output.push((length as u8 & 0x7f) | 0x80);
        length >>= 7;
    }

    output.push(length as u8);
    output.extend_from_slice(bytes);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_exact_wire_schema() {
        let mut expected = b"\x0a\x22\x0a\x20\x0a\x03abc\x12\x19".to_vec();
        expected.extend_from_slice(b"@defold.nvim/debugger.lua");
        assert_eq!(encode_run_script(b"abc"), expected);
        let mut encoded = Vec::new();
        encode_bytes_field(&mut encoded, 1, &[42; 128]);
        assert_eq!(&encoded[..3], &[0x0a, 0x80, 0x01]);
        for port in [1, 65535] {
            let payload = debugger_payload(port, "127.0.0.1").unwrap();
            assert!(payload.len() <= 1024);
            assert!(
                String::from_utf8_lossy(&payload)
                    .contains(&format!("debugger.start({port}, \"127.0.0.1\")"))
            );
        }
    }
}
