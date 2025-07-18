#!/usr/bin/env bash

if [[ "$#" -ne 1 && "$#" -ne 2 ]]; then
    echo "Usage: $0 <file> [line]"
    echo "    <file>:  The file to open"
    echo "    [line]:  Optional. The line number to open the file at"
    exit 1
fi

class_name="com.defold.neovim"

launch_neovim() {
    local server_name="$1"
    local file_name="\"$2\""

    if command -v ghostty >/dev/null 2>&1; then
        ghostty --class="$class_name" -e nvim --listen "$server_name" --remote "$file_name"
    elif command -v foot >/dev/null 2>&1; then
        foot --app-id="$class_name" -e nvim --listen "$server_name" --remote "$file_name"
    elif command -v kitty >/dev/null 2>&1; then
        kitty --class="$class_name" nvim --listen "$server_name" --remote "$file_name"
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty --class="$class_name" -e nvim --listen "$server_name" --remote "$file_name"
    elif command -v st >/dev/null 2>&1; then
        st -c "$class_name" -e nvim --listen "$server_name" --remote "$file_name"
    else
        echo "No supported terminal found, aborting..."
        exit 1
    fi
}

switch_focus() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch focuswindow class:"$class_name"
    else
        echo "No supported focus switcher found, do nothing..."
    fi
}

file_name="$1"

root_dir="${XDG_CACHE_HOMES:-$HOME/.cache}/defold.nvim"
mkdir -p "$root_dir"

if [[ "$#" -eq 3 ]]; then
    line="$2"
    command="edit +$line $file_name"
else
    command="edit $file_name"
fi

server_name="$root_dir/neovim"

if [[ -e "$server_name" ]]; then
    nvim --server "$server_name" --remote-send "<C-\\><C-n>:$command<CR>"
else
    launch_neovim "$server_name" "$file_name"
fi

switch_focus
