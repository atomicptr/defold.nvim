#!/usr/bin/env bash
{BRIDGE_PATH} launch-neovim "{LAUNCH_CONFIG}" "$(realpath .)" "$1" $2
