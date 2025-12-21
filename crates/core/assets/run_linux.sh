#!/usr/bin/env bash
"{BRIDGE_PATH}" {DEBUG_FLAG} launch-neovim {LAUNCH_PRE_ARGS} "$(realpath .)" "$1" $2 {LAUNCH_POST_ARGS}
