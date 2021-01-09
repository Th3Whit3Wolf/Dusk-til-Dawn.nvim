# Dusk-til-Dawn.nvim

Automatically change colorscheme based on time

## Install

### Vim Plug

```vim
Plug 'Th3Whit3Wolf/Dusk-til-Dawn.nvim'

" And then somewhere in your init.vim
lua require'Dusk-til-Dawn'.colorschemeManager()()
```

### Minpac

```vim
call minpac#add('Th3Whit3Wolf/Dusk-til-Dawn.nvim')

" And then somewhere in your init.vim
lua require'Dusk-til-Dawn'.colorschemeManager()()
```

### Vim Packages

In the terminal execute this command.

```sh
cd ~/.local/share/nvim/site/pack/start/
git clone https://github.com/Th3Whit3Wolf/Dusk-til-Dawn.nvim
```

In your `init.vim` add the following

```vim
" And then somewhere in your init.vim after the above command
lua require'Dusk-til-Dawn'.colorschemeManager()()
```

## Configuration

|          Configuration          |               Function              |  Default  |
| :------------------------------ | :---------------------------------- | :-------- |
| `g:dusk_til_dawn_morning`       | Sets time when day begins           | 7  (7 am) |
| `g:dusk_til_dawn_night`         | Sets time when day ends             | 19 (7 pm) |
| `g:dusk_til_dawn_light_theme`   | Sets light theme                    | morning   |
| `g:dusk_til_dawn_dark_theme`    | Sets dark theme                     | evening   |
| `g:dusk_til_dawn_debug`         | Turns on debug mode (strobe effect) | false     |

## Commands

|      Commands     |      Function       |
| :---------------- | :------------------ |
| ChangeColor       | Toggles colorscheme |

## NOTE

- Vim is not supported because the plugin is written in lua.
- Will set colorscheme on initialization (no need to use `colorscheme x` just set colorscheme with `g:dusk_til_dawn_light_theme` and `g:dusk_til_dawn_dark_theme`)

## Special Thanks

- [Jonathan Stoler](https://github.com/jonstoler) - I've been using a modified version of their [werewolf.vim](https://github.com/jonstoler/werewolf.vim) to change colorschemes for a while and inspired me to make this plugin.
- [ms-jpq](https://github.com/ms-jpq) - Their [Neovim Async Tutorial](https://ms-jpq.github.io/neovim-async-tutorial/) article was a major help in refactor my plugin.
