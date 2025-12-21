@echo off
{BRIDGE_PATH} {DEBUG_FLAG} launch-neovim {LAUNCH_PRE_ARGS} "%CD%" "%~1" %2 {LAUNCH_POST_ARGS}
