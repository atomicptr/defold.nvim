# defold.nvim

A Neovim plugin that just works, enabling you to use Neovim as an external editor for the [Defold game engine](https://defold.com)

## Features

- Just works, no external tools required
- Inject Defold API annotations to the Neovim LSP
- Add support for Defolds various file formats

## Install

### Lazy

```lua
{
    "atomicptr/defold.nvim",
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

## Special thanks

- [astrochili/defold-annotations](https://github.com/astrochili/defold-annotations)

## License

GPLv3
