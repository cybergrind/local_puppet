return {
	-- common
	{
		'github/copilot.vim',
		branch = 'release',
	},
	{
		'preservim/nerdtree',
		cmd = 'NERDTreeToggle',
	},
	{
		'ctrlpvim/ctrlp.vim',
	},
	{
		'neoclide/coc.nvim',
		branch = 'release',
	},
	-- { 'neovim/nvim-lspconfig' },
	-- { 'ycm-core/youcompleteme', build = 'python3 install.py' },
	-- { 'xolox/vim-easytags' },
	{
		'majutsushi/tagbar',
	},
	{
		'easymotion/vim-easymotion',
	},
	{
		'junegunn/fzf',
		dir = '~/.fzf',
		build = './install --all',
	},
	{
		'junegunn/fzf.vim',
	},
	{
		'terryma/vim-multiple-cursors',
	},
	{
		'vim-airline/vim-airline',
	},
	{
		'vim-airline/vim-airline-themes',
	},
	{
		'scrooloose/nerdcommenter',
	},
	{
		'matze/vim-move',
	},
	{
		'raimondi/delimitmate',
	},
	{
		'mattn/emmet-vim',
	},
	{
		'scrooloose/syntastic',
	},
	{
		'tpope/vim-surround',
	},
	-- { 'sirver/ultisnips' },
	-- { 'honza/vim-snippets' },
	{
		'xolox/vim-session',
		dependencies = { 'xolox/vim-misc' },
	},
	{
		'vim-scripts/SyntaxAttr.vim',
	},
	{
		'dyng/ctrlsf.vim',
	},
	{
		'rking/ag.vim',
	},
	{
		'godlygeek/tabular',
	},

	-- javascript
	{
		'pangloss/vim-javascript',
	},

	-- html
	{
		'othree/html5.vim',
	},

	-- twig
	{
		'evidens/vim-twig',
	},

	-- css
	{
		'mtscout6/vim-tagbar-css',
	},

	-- colors
	{
		'damage220/solas.vim',
	},
	{
		'nanotech/jellybeans.vim',
	},
	{
		'morhetz/gruvbox',
	},
	{
		'joshdick/onedark.vim',
	},
	{
		'jonathanfilip/vim-lucius',
	},
}
