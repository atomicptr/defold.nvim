{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    pkg-config
  ];

  buildInputs = with pkgs; [
    openssl.dev
  ];

  RUST_LOG = "info,defold_nvim=debug";
  RUST_BACKTRACE = "1";
}
