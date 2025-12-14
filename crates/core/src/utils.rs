use anyhow::{Context, Result};
use sha3::{Digest, Sha3_256};

pub fn sha3(str: &str) -> String {
    let mut hasher = Sha3_256::new();
    hasher.update(str.as_bytes());
    let result = hasher.finalize();

    format!("{:x}", result)
}

pub fn project_id(root_dir: &str) -> Result<String> {
    Ok(sha3(root_dir)
        .get(0..8)
        .context("could not create project id")?
        .to_string())
}

pub fn classname(root_dir: &str) -> Result<String> {
    Ok(format!("com.defold.nvim.{}", project_id(root_dir)?))
}
