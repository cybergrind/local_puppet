" curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
" sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

" :PlugInstall

set nocompatible
filetype off

if !has('nvim')
" remember last position
source $VIMRUNTIME/defaults.vim
endif

call plug#begin()

" common
Plug 'github/copilot.vim', {'branch': 'main'}

Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'ctrlpvim/ctrlp.vim'

Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Plug 'neovim/nvim-lspconfig'
" Plug 'ycm-core/youcompleteme', {'do': 'python3 install.py'}
" Plug 'xolox/vim-easytags'
Plug 'majutsushi/tagbar'
Plug 'easymotion/vim-easymotion'

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'scrooloose/nerdcommenter'
Plug 'matze/vim-move'
Plug 'raimondi/delimitmate'
Plug 'mattn/emmet-vim'
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-surround'
" Plug 'sirver/ultisnips' | Plug 'honza/vim-snippets'
Plug 'xolox/vim-session'
Plug 'xolox/vim-misc'
Plug 'vim-scripts/SyntaxAttr.vim'
Plug 'dyng/ctrlsf.vim'
Plug 'rking/ag.vim'
Plug 'godlygeek/tabular'

" javascript
Plug 'pangloss/vim-javascript'

" html
Plug 'othree/html5.vim'

" twig
Plug 'evidens/vim-twig'

" css
Plug 'mtscout6/vim-tagbar-css'

" colors
Plug 'damage220/solas.vim'
Plug 'nanotech/jellybeans.vim'
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'
Plug 'jonathanfilip/vim-lucius'


call plug#end()

filetype plugin indent on

" settings
set tabstop=4
set softtabstop=4
set shiftwidth=4
set autoread
set autoindent
set smartindent
set rnu
set laststatus=2
set timeoutlen=500
set ttimeoutlen=0
set keymap=russian-jcukenwin
set iminsert=0
set imsearch=0
set encoding=utf-8
set updatetime=500
set noswapfile
set splitright
set splitbelow
set nocompatible
set tags=./tags;
set ignorecase
set hidden
set hlsearch
set incsearch
set cursorline
set pumheight=10
set fillchars+=vert:\
let mapleader=","
filetype off
filetype plugin on
filetype plugin indent on
" autocmd CompleteDone * pclose

" color
syntax enable
set background=dark
set t_Co=256

try
  colorscheme gruvbox
  catch
endtry


" abbreviations
abbr help tab help

" mappings
imap df <Esc>l
nnoremap <Esc> <Esc>:w<CR>
nnoremap <M-i> :only<CR>:vsp<CR>

nnoremap 2o o<CR>
nnoremap 2O O<Esc>O
nnoremap tm :tabm +1<CR>
nnoremap tM :tabm -1<CR>
nnoremap J L

nnoremap K H
nnoremap H gT
nnoremap L gt
nnoremap F :Files<CR>
nnoremap ff :CtrlP<CR>
nnoremap ft :CtrlPBufTag<CR>
nnoremap fb :CtrlPBuffer<CR>
nmap fs <Plug>(easymotion-s)
nmap fl <Plug>(easymotion-sl)
nnoremap fc :NERDTreeFind<CR>
nnoremap fp :CtrlSF
nnoremap <C-h> :noh<CR>
map <C-?> <plug>NERDCommenterComment
map <C-_> <plug>NERDCommenterToggle
nnoremap <C-m> :TagbarToggle<CR>
nnoremap <C-p> :NERDTreeToggle<CR>
nnoremap <C-g> :call SyntaxAttr()<CR>
inoremap <C-j> <C-n>
inoremap <C-k> <C-p>
cnoremap <C-j> <C-n>
cnoremap <C-k> <C-p>

if has('nvim')
nnoremap <F4> :tabe ~/.config/nvim/init.vim<CR>:tabm 0<CR>
else
nnoremap <F4> :tabe ~/.vimrc<CR>:tabm 0<CR>
endif

nnoremap <F5> :w<CR>:so $MYVIMRC<CR>

" leader = ,
noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>0 :tablast<cr>
nnoremap <Space>h <C-w>h
nnoremap <Space>l <C-w>l
nnoremap <Space>j <C-w>j
nnoremap <Space>k <C-w>k
nnoremap ZX :qa<CR>

" nerdtree
let NERDTreeAutoDeleteBuffer = 1

" move
let g:move_key_modifier = 'C'

" youcompleteme
let g:ycm_server_python_interpreter='python'
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_key_list_select_completion = ['<Down>']

" emmet
let g:user_emmet_expandabbr_key = '<C-e>'

" airline
let g:airline_theme='angr'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#tab_min_count = 0
let g:airline#extensions#tabline#formatter = 'unique_tail'
let g:airline#extensions#tabline#show_buffers = 0
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline_section_warning = ''
let g:airline_section_error = ''
let g:airline#extensions#tabline#show_close_button = 0
let g:airline#extensions#tabline#left_alt_sep = ''
let g:airline#extensions#tagbar#enabled = 0
let g:airline#extensions#tabline#show_tab_nr = 1
let g:airline#extensions#tabline#tab_nr_type = 1

" easymotion
let g:EasyMotion_smartcase = 1
let g:EasyMotion_do_shade = 0
hi link EasyMotionTarget Search
hi EasyMotionTarget2First ctermfg=202 ctermbg=None cterm=None
hi EasyMotionTarget2Second ctermfg=202 ctermbg=None cterm=None

" session
let g:session_autoload = 'yes'
let g:session_autosave = 'yes'
let g:session_autosave_periodic = 5
let g:session_autosave_silent = 1
let g:session_default_to_last = 1

" NERDCommenter
let g:NERDSpaceDelims = 1

" html
au BufNewFile,BufRead *.tpl set filetype=html syntax=php

" syntastic
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" tagbar
let g:tagbar_sort = 0
let g:tagbar_width = 35
let g:tagbar_iconchars = ['+', '-']
let g:tagbar_map_close = '<C-m>'
let g:tagbar_type_javascript = {
\'ctagstype':'JavaScript',
    \'kinds' : [
        \'f:functions',
        \'c:classes',
        \'m:methods',
        \'p:properties'
    \]
\}

" delimitmate
let delimitMate_expand_cr = 1
let delimitMate_expand_space = 1
au FileType vim,html let b:delimitMate_matchpairs = "(:),[:],{:},<:>,>:<"

" NERDTree
" let g:NERDTreeDirArrowExpandable = '+'
" let g:NERDTreeDirArrowCollapsible = '-'

" ctrlp
let g:ctrlp_by_filename = 1
let g:ctrlp_working_path_mode = 'wr'
let g:ctrlp_map = ''
let g:ctrlp_buftag_types = {
    \'php': '--php-kinds=icdf'
\}

" ctrlsf
let g:ctrlsf_position = 'right'

" leader keys
nmap <leader><space> <Plug>(easymotion-s)

" easytags
let g:easytags_file = './tags'
let g:easytags_auto_highlight = 0
let g:easytags_events = ['BufWritePost']
let g:easytags_async = 1


" " Copy to clipboard
vnoremap  <leader><leader>y  "+y
nnoremap  <leader><leader>Y  "+yg_
nnoremap  <leader><leader>y  "+y
nnoremap  <leader><leader>yy  "+yy

" " Paste from clipboard
nnoremap <leader><leader>p "+p
nnoremap <leader><leader>P "+P
vnoremap <leader><leader>p "+p
vnoremap <leader><leader>P "+P
