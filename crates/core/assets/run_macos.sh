#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/usr/local/bin:$PATH"
"{BRIDGE_PATH}" {DEBUG_FLAG} launch-neovim {LAUNCH_PRE_ARGS} "$(realpath .)" "$1" $2 {LAUNCH_POST_ARGS}
