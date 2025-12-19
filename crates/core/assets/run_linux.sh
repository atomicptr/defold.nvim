#!/usr/bin/env bash
{BRIDGE_PATH} {DEBUG_FLAG} launch-neovim {LAUNCH_ARGS} "$(realpath .)" "$1" $2
