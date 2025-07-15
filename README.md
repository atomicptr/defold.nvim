# defold.nvim

Use Neovim as your external editor for the [Defold game engine](https://defold.com).

## Features

- **Code Hot-Reloading**: Instantly see code changes reflected in Defold.
- **Defold Control via Neovim**: Execute Defold commands directly from Neovim using custom user commands.
- **LSP Integration**: Leverage Defold API annotations within Neovim's Language Server Protocol
- **File Format Support**: Seamlessly work with Defold's diverse range of file formats.

## System Requirements

This plugin is designed for Linux environments, though it might function on macOS (untested). You'll also need curl and either lsof or ss installed on your system.

## Install

### Lazy.nvim

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

    -- configuration
    opts = {
        -- enables code hot reloading (default: true)
        hot_reload_enabled = true,

        -- enables registering commands for every editor command via :DefoldCmd... (default: true)
        register_editor_commands = true,
    }
}
```

## Setup Neovim

Copy [neovim-defold.sh](./neovim-defold.sh) into your path and set it up in Defold like this:

In Defold head to **File** > **Preferences** > **Code**

![Defold Settings](./.github/defold-settings.png)

## Available Commands

Here's how you can interact with Defold directly from Neovim:

* **:DefoldSend `<command>`**
    This command lets you send any arbitrary command directly to your Defold editor. Use this for scripting or keybindings. For example, use **`:DefoldSend build`** to trigger build & run.

* **:DefoldCmd...**
    The plugin automatically registers all available Defold commands within Neovim, each prefixed with `:DefoldCmd`. For instance, you can use **`:DefoldCmdBuild`** to build & run your game. This might fail if the Defold editor isn't running, use the next command to reload the available commands.

* **:DefoldRefreshCommands**
    Use this to fetch and reload the list of commands from the Defold editor. All of these will be available using the **`:DefoldCmd...`** prefix.

## Special thanks

- [astrochili/defold-annotations](https://github.com/astrochili/defold-annotations)

## License

GPLv3
