use std::{fs, path::PathBuf};

use anyhow::{Result, bail};
use walkdir::{DirEntry, WalkDir};

use crate::{
    miniproto::{self, Value},
    path,
};

pub fn fetch_input_bindings(root_dir: &PathBuf) -> Result<Vec<String>> {
    let bindings = WalkDir::new(root_dir)
        .into_iter()
        .filter_entry(|e| !path::is_hidden(e))
        .filter_map(Result::ok)
        .map(DirEntry::into_path)
        .filter(|p| p.is_file())
        .filter_map(|p| match p.extension() {
            Some(ext) if ext.to_string_lossy() == "input_binding" => Some(p),
            _ => None,
        })
        .collect::<Vec<_>>();

    let Some(binding_file) = bindings.first() else {
        bail!(
            "could not find .input_binding file in {}",
            root_dir.display()
        );
    };

    let data = fs::read_to_string(binding_file)?;

    let message = miniproto::parse(&data)?;

    let mut bindings = Vec::new();

    for v in message.get("key_trigger") {
        let Value::Message(value) = v else {
            continue;
        };

        let Some(action) = value.first_string("action") else {
            continue;
        };

        bindings.push(action);
    }

    bindings.sort();
    bindings.dedup();

    Ok(bindings)
}
