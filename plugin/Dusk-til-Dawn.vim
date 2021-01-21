
if exists('g:dusk_til_dawn_loaded') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

if !has('nvim')
    echohl Error
    echom "Sorry this plugin only works with versions of neovim that support lua"
    echohl clear
    finish
endif

let g:dusk_til_dawn_loaded = 1

command! ChangeColor lua require 'Dusk-til-Dawn'.changeColors()

let &cpo = s:save_cpo
unlet s:save_cpo