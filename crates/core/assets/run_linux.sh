#!/usr/bin/env bash
{BRIDGE_PATH} launch-neovim {LAUNCH_ARGS} "$(realpath .)" "$1" $2
