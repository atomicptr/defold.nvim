#!/usr/bin/env bash
export PATH="/usr/bin:/usr/local/bin:$PATH"
{BRIDGE_PATH} {DEBUG_FLAG} launch-neovim {LAUNCH_PRE_ARGS} "$(realpath .)" "$1" $2 {LAUNCH_POST_ARGS}
