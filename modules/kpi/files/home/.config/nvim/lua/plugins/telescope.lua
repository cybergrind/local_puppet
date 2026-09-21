local function open_file_browser()
	require('telescope').extensions.file_browser.file_browser({
		path = '%:p:h',
		select_buffer = true,
		hidden = true,
		grouped = true,
		respect_gitignore = false,
		no_ignore = true,
		follow_symlinks = true,
	})
end

local function project_root()
	return vim.fs.root(0, { '.git', '.projectile', '.hg' }) or vim.uv.cwd()
end

-- Equivalent of projectile-find-file: recursive fuzzy find from the project root.
local function project_find_file()
	require('telescope.builtin').find_files({
		cwd = project_root(),
		hidden = true,
		find_command = { 'rg', '--files', '--hidden', '--glob', '!.git/*' },
	})
end

-- Equivalent of projectile grep (<leader>ps / <leader>pg): live grep from the project root.
local function project_live_grep()
	require('telescope.builtin').live_grep({ cwd = project_root() })
end

return {
	{
		'nvim-telescope/telescope.nvim',
		dependencies = {
			'nvim-lua/plenary.nvim',
			'nvim-telescope/telescope-file-browser.nvim',
		},
		cmd = { 'Telescope' },
		keys = {
			{
				'<leader>f',
				open_file_browser,
				desc = 'File browser (C-x C-f style)',
			},
			{
				'<C-x><C-f>',
				open_file_browser,
				desc = 'File browser (C-x C-f style)',
			},
			{
				'<leader>pf',
				project_find_file,
				desc = 'Project find file (projectile-find-file)',
			},
			{
				'<leader>ps',
				project_live_grep,
				desc = 'Project grep (projectile-grep)',
			},
		},
		config = function()
			local telescope = require('telescope')
			local fb_actions = telescope.extensions.file_browser.actions
			local action_state = require('telescope.actions.state')

			local bs_keys = vim.api.nvim_replace_termcodes('<BS>', true, false, true)
			local function backspace_or_parent(prompt_bufnr)
				local picker = action_state.get_current_picker(prompt_bufnr)
				if picker:_get_prompt() == '' then
					fb_actions.goto_parent_dir(prompt_bufnr)
				else
					vim.api.nvim_feedkeys(bs_keys, 'tn', false)
				end
			end

			telescope.setup({
				extensions = {
					file_browser = {
						hijack_netrw = false,
						grouped = true,
						hidden = true,
						no_ignore = true,
						follow_symlinks = true,
						mappings = {
							['i'] = {
								['<BS>'] = backspace_or_parent,
								['<Tab>'] = fb_actions.open_dir,
							},
						},
					},
				},
			})

			telescope.load_extension('file_browser')
		end,
	},
}
