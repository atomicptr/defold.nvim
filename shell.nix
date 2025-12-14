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

  RUST_BACKTRACE = "1";
  RUST_LOG = "debug";
}
