#!/usr/bin/env bash
export PATH="/usr/bin:/usr/local/bin:$PATH"
{BRIDGE_PATH} launch-neovim "{LAUNCH_CONFIG}" "$(realpath .)" "$1" $2
