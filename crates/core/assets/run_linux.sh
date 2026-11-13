#!/usr/bin/env bash
{BRIDGE_PATH} {DEBUG_FLAG} launch-neovim --show-error-dialog {LAUNCH_PRE_ARGS} "$(realpath .)" "$1" $2 {LAUNCH_POST_ARGS}
