# defold.nvim

A Neovim plugin that just works, enabling you to use Neovim as an external editor for the [Defold game engine](https://defold.com)

## Features

- Code hot reload
- Control Defold using Neovim user commands
- Inject Defold API annotations to the Neovim LSP
- Add support for Defolds various file formats

## System Requirements

- Linux (might work on macOS, untested)
- ``curl``
- ``lsof`` or ``ss``

## Install

### Lazy

```lua
{
    "atomicptr/defold.nvim",
    -- this will make sure this plugin only loads when you are in a defold project
    cond = function()
        local root_dir = vim.fs.root(0, { "game.project", ".git" })
        if root_dir == nil then
            return false
        end
        return vim.fn.filereadable(root_dir .. "/game.project") == 1
    end,
}
```

## Setup Neovim

We might still need to make a more generic script but here is what I'm using: https://gist.github.com/atomicptr/5077153f622baa60a95893faf4784403

It opens Neovim through ghostty and switches focus (in Hyprland) to it

## Available Commands

- **:DefoldSend cmd** - Sends a command directly to the Defold editor e.g. **:DefoldSend build** this, you should use this for scripts, keybinds etc
- **:DefoldCmd...** - The plugin automatically registers all available Defold commands to Neovim, this might fail, run **:DefoldRefreshCommands** to reload the list. Try **:DefoldCmdBuild**
- **:DefoldRefreshCommands** - Fetches commands from the editor, they are all prefixed with **:DefoldCmd...**

## Special thanks

- [astrochili/defold-annotations](https://github.com/astrochili/defold-annotations)

## License

GPLv3
