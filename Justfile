watch:
    watchexec -w src -r 'just build-and-link'

build:
    cargo build

link:
    #!/usr/bin/env bash
    set -e

    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        cp -f "$(pwd)/target/debug/defold_nvim.dll" lua/defold/sidecar.dll
    elif [[ "$(uname)" == "Darwin" ]]; then
        cp -f "$(pwd)/target/debug/libdefold_nvim.dylib" lua/defold/sidecar.so
    else
        cp -f "$(pwd)/target/debug/libdefold_nvim.so" lua/defold/sidecar.so
    fi

build-and-link: build link
