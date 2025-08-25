-- Leader key
vim.g.mapleader = ","


require("config.lazy")


-- Basic settings
local opt = vim.opt
opt.compatible = false
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.autoread = true
opt.autoindent = true
opt.smartindent = true
opt.relativenumber = true
opt.laststatus = 2
opt.timeoutlen = 500
opt.ttimeoutlen = 0
opt.keymap = "russian-jcukenwin"
opt.iminsert = 0
opt.imsearch = 0
opt.encoding = "utf-8"
opt.updatetime = 500
opt.swapfile = false
opt.splitright = true
opt.splitbelow = true
opt.tags = "./tags;"
opt.ignorecase = true
opt.hidden = true
opt.hlsearch = true
opt.incsearch = true
opt.cursorline = true
opt.pumheight = 10
opt.fillchars:append("vert:|")
opt.background = "dark"
opt.termguicolors = true

-- Enable syntax and filetype
vim.cmd("syntax enable")
vim.cmd("filetype plugin indent on")

-- Colorscheme
vim.cmd([[
  try
    colorscheme gruvbox
  catch
  endtry
]])

-- Abbreviations
vim.cmd("abbr help tab help")

-- Key mappings
local keymap = vim.keymap.set

-- Insert mode mappings
keymap("i", "df", "<Esc>l")
keymap("i", "<C-j>", "<C-n>")
keymap("i", "<C-k>", "<C-p>")

-- Normal mode mappings
keymap("n", "<Esc>", "<Esc>:w<CR>")
keymap("n", "<M-i>", ":only<CR>:vsp<CR>")
keymap("n", "<C-x>b", ":Buffers<CR>")
keymap("n", "<C-x><C-b>", ":Buffers<CR>")
keymap("n", "<leader>.", "<C-w><C-w>")
keymap("n", "<leader><leader>R", ":e!<CR>")
keymap("n", '"p', ':reg <bar> exec \'normal! "\'.input(\'>\').\'p\'<CR>')
keymap("n", "2o", "o<CR>")
keymap("n", "2O", "O<Esc>O")
keymap("n", "tm", ":tabm +1<CR>")
keymap("n", "tM", ":tabm -1<CR>")
keymap("n", "J", "L")
keymap("n", "K", "H")
keymap("n", "H", "gT")
keymap("n", "L", "gt")
keymap("n", "F", ":Files<CR>")
keymap("n", "ff", ":CtrlP<CR>")
keymap("n", "ft", ":CtrlPBufTag<CR>")
keymap("n", "fb", ":CtrlPBuffer<CR>")
keymap("n", "fc", ":NERDTreeFind<CR>")
keymap("n", "fp", ":CtrlSF")
keymap("n", "<leader>a", ":Ag ")
keymap("n", "<C-h>", ":noh<CR>")
keymap("n", "<C-m>", ":TagbarToggle<CR>")
keymap("n", "<C-p>", ":NERDTreeToggle<CR>")
keymap("n", "<C-g>", ":call SyntaxAttr()<CR>")
keymap("n", "<F4>", ":tabe ~/.config/nvim/init.lua<CR>:tabm 0<CR>")
keymap("n", "<F5>", ":w<CR>:so $MYVIMRC<CR>")
keymap("n", "<Space>h", "<C-w>h")
keymap("n", "<Space>l", "<C-w>l")
keymap("n", "<Space>j", "<C-w>j")
keymap("n", "<Space>k", "<C-w>k")
keymap("n", "ZX", ":qa<CR>")

-- Leader number mappings
for i = 1, 9 do
  keymap("n", "<leader>" .. i, i .. "gt")
end
keymap("n", "<leader>0", ":tablast<cr>")

-- Visual and normal mode mappings for clipboard
keymap({"n", "v"}, "<leader><leader>y", '"+y')
keymap("n", "<leader><leader>Y", '"+yg_')
keymap("n", "<leader><leader>yy", '"+yy')
keymap({"n", "v"}, "<leader><leader>p", '"+p')
keymap({"n", "v"}, "<leader><leader>P", '"+P')

-- Command mode mappings
keymap("c", "<C-j>", "<C-n>")
keymap("c", "<C-k>", "<C-p>")

-- Map mode mappings (for plugins)
vim.api.nvim_set_keymap("n", "fs", "<Plug>(easymotion-s)", {})
vim.api.nvim_set_keymap("n", "fl", "<Plug>(easymotion-sl)", {})
vim.api.nvim_set_keymap("n", "<leader><space>", "<Plug>(easymotion-s)", {})
vim.api.nvim_set_keymap("", "<C-?>", "<plug>NERDCommenterComment", {})
vim.api.nvim_set_keymap("", "<C-_>", "<plug>NERDCommenterToggle", {})

-- Plugin configurations
vim.g.NERDTreeAutoDeleteBuffer = 1
vim.g.move_key_modifier = 'C'

-- YouCompleteMe (currently disabled)
vim.g.ycm_server_python_interpreter = 'python'
vim.g.ycm_autoclose_preview_window_after_completion = 1
vim.g.ycm_key_list_select_completion = {'<Down>'}

-- Emmet
vim.g.user_emmet_expandabbr_key = '<C-e>'

-- Airline
vim.g.airline_theme = 'angr'
vim.g.airline_powerline_fonts = 1
vim.g['airline#extensions#tabline#enabled'] = 1
vim.g['airline#extensions#tabline#tab_min_count'] = 0
vim.g['airline#extensions#tabline#formatter'] = 'unique_tail'
vim.g['airline#extensions#tabline#show_buffers'] = 0
vim.g['airline#extensions#tabline#fnamemod'] = ':t'
vim.g.airline_section_warning = ''
vim.g.airline_section_error = ''
vim.g['airline#extensions#tabline#show_close_button'] = 0
vim.g['airline#extensions#tabline#left_alt_sep'] = ''
vim.g['airline#extensions#tagbar#enabled'] = 0
vim.g['airline#extensions#tabline#show_tab_nr'] = 1
vim.g['airline#extensions#tabline#tab_nr_type'] = 1

-- EasyMotion
vim.g.EasyMotion_smartcase = 1
vim.g.EasyMotion_do_shade = 0
vim.cmd("hi link EasyMotionTarget Search")
vim.cmd("hi EasyMotionTarget2First ctermfg=202 ctermbg=None cterm=None")
vim.cmd("hi EasyMotionTarget2Second ctermfg=202 ctermbg=None cterm=None")

-- Session
vim.g.session_autoload = 'yes'
vim.g.session_autosave = 'yes'
vim.g.session_autosave_periodic = 5
vim.g.session_autosave_silent = 1
vim.g.session_default_to_last = 1

-- NERDCommenter
vim.g.NERDSpaceDelims = 1

-- Syntastic
vim.g.syntastic_always_populate_loc_list = 1
vim.g.syntastic_auto_loc_list = 0
vim.g.syntastic_check_on_open = 1
vim.g.syntastic_check_on_wq = 0

-- Tagbar
vim.g.tagbar_sort = 0
vim.g.tagbar_width = 35
vim.g.tagbar_iconchars = {'+', '-'}
vim.g.tagbar_map_close = '<C-m>'
vim.g.tagbar_type_javascript = {
  ctagstype = 'JavaScript',
  kinds = {
    'f:functions',
    'c:classes',
    'm:methods',
    'p:properties'
  }
}

-- DelimitMate
vim.g.delimitMate_expand_cr = 1
vim.g.delimitMate_expand_space = 1

-- CtrlP
vim.g.ctrlp_by_filename = 1
vim.g.ctrlp_working_path_mode = 'wr'
vim.g.ctrlp_map = ''
vim.g.ctrlp_buftag_types = {
  php = '--php-kinds=icdf'
}

-- CtrlSF
vim.g.ctrlsf_position = 'right'

-- Easytags
vim.g.easytags_file = './tags'
vim.g.easytags_auto_highlight = 0
vim.g.easytags_events = {'BufWritePost'}
vim.g.easytags_async = 1

-- Autocommands
vim.cmd([[
  autocmd BufNewFile,BufRead *.tpl set filetype=html syntax=php
  autocmd FileType vim,html let b:delimitMate_matchpairs = "(:),[:],{:},<:>,>:<"
]])