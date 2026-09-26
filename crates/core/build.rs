use std::{env, fs, path::Path};

fn main() {
    let version = env!("CARGO_PKG_VERSION");
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let dest_path = Path::new(&manifest_dir)
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .join("lua")
        .join("defold")
        .join("version.lua");

    println!("cargo:rerun-if-changed=Cargo.toml");

    fs::write(
        &dest_path,
        format!("-- Automatically generated don't edit\nreturn \"{version}\""),
    )
    .expect("could not write {dest_path:?}");

    println!("cargo:warning=Set {dest_path:?} to {version}");
}
