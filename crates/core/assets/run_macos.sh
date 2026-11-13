#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/usr/local/bin:$PATH"
{ENV}{BRIDGE_PATH} {DEBUG_FLAG} launch-neovim --show-error-dialog {LAUNCH_PRE_ARGS} "$(realpath .)" "$1" $2 {LAUNCH_POST_ARGS}
