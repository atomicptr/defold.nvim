#!/bin/sh
{ENV}{BRIDGE_PATH} {DEBUG_FLAG} launch-neovim --show-error-dialog {LAUNCH_PRE_ARGS} "$(pwd -P)" "$1" $2 {LAUNCH_POST_ARGS}
