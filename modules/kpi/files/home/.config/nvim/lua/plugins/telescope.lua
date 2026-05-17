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
				function()
					require('telescope').extensions.file_browser.file_browser({
						path = '%:p:h',
						select_buffer = true,
						hidden = true,
						grouped = true,
						respect_gitignore = false,
					})
				end,
				desc = 'File browser (C-x C-f style)',
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
