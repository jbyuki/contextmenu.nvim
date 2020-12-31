--
-- Plugin: contextmenu.nvim 
-- Description: A simple to use lua library to have contextual menu in 
--              your Neovim plugin
-- 
-- Usage:
-- 		local choices = {"choice 1", choice 2"}
-- 		require"contextmenu".open(choices,
-- 			on_submit = function(chosen) 
-- 				print("Final choice " .. choices[chosen])
-- 			end
-- 		)
local M = {}

--@private
-- Create a floating window and its buffer.
-- Compute the window size according to the elements and
-- options passed.
local function create_float_win(choices, opts)
	-- Create scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- Compute width
	local width = 0
	for _, o in ipairs(choices) do
		local w = vim.api.nvim_strwidth(o)
		width = math.max(width, (opts.margin_left or 0) + w + (opts.margin_right or 0))
	end

	if opts.max_width then
		width = math.min(width, opts.max_width)
	end

	-- Compute height
	local height = #choices

	if opts.max_height then
		height = math.min(height, opts.max_height)
	end

	-- Create float window
	local win_opts = {
		relative =  opts.relative or 'cursor', 
		anchor =  opts.anchor or nil, 
		width =  width, 
		height = height, 
		col = opts.col or 2,
		row = opts.row or 2, 
		style =  opts.style or 'minimal',
	}

	local border_opts = {
		title = opts.title or "",
		width = 1,
		topleft  = '╭',
		topright = '╮',
		top      = '─',
		left     = '│',
		right    = '│',
		botleft  = '╰',
		botright = '╯',
		bot      = '─',
	}

	-- use borders if plenary is installed
	local shadow_win = -1
	pcall(function()
		local Border = require("plenary.window.border")
		shadow_win = vim.api.nvim_open_win(buf, false, win_opts)
		Border:new(buf, shadow_win, win_opts, border_opts)
	end)

	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.api.nvim_win_set_option(win, "cursorline", true)
	vim.api.nvim_win_set_option(win, "winhl", "CursorLine:" .. (opts.hl_group or "TermCursor"))

	return buf, win, shadow_win
end

--@private
-- Adds padding on the left to every elements
-- according to opts.margin_left
local function pad_text(choices, opts)
	if opts.margin_left then
		for i=1,#choices do
			for _=1,opts.margin_left do
				choices[i] = " " .. choices[i]
			end
		end
	end
end

--@private
-- Contains the focused context menu
local focused = {}

-- Open a context menu
--
--@param choices a table of strings
--@param opts dictionary with fields
--  	- on_close callback, no argument, called when closed or lose focus
--  	- on_submit callback, 1 argument, index of chosen element (1-based)
--		- hl_group highlight group for the selected line, preferably the cursor highlight group
--  	- max_width maximum width for context menu (including margin)
--  	- max_height maximum height for context menu
--  	- margin_left adds spaces to the left
--  	- margin_right adds spaces to the left
--  	- relative relative argument for |nvim_open_win|
--  	- title context menu title
--  	- anchor anchor argument for |nvim_open_win|
--  	- row row argument for |nvim_open_win|
--  	- col col argument for |nvim_open_win|
function M.open(choices, opts)
	vim.validate {
		choices = {choices, "t"},
		opts = {opts, "t", true},
	}

	opts = opts or {}

	vim.validate {
		["opts.hl_group"] = { opts.hl_group, "s", true },
		["opts.max_width"] = { opts.max_width, "n", true },
		["opts.max_height"] = { opts.max_height, "n", true },
		["opts.margin_left"] = { opts.margin_left, "n", true },
		["opts.margin_right"] = { opts.margin_right, "n", true },
		["opts.relative"] = { opts.relative, "s", true },
		["opts.anchor"] = { opts.anchor, "n", true },
		["opts.row"] = { opts.row, "n", true },
		["opts.col"] = { opts.col, "n", true },
		["opts.title"] = { opts.title, "s", true },
		["opts.on_close"] = { opts.on_close, "f", true },
		["opts.on_submit"] = { opts.on_submit, "f", true },
	}
	
	-- Leave a highlight where the cursor was
	local old_buf = vim.api.nvim_get_current_buf()
	local ns_cursor = M.display_cursor()

	-- Display floating with text
	local buf, win, shadow_win = create_float_win(choices, opts)

	pad_text(choices, opts)
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, choices)

	focused = {
		win = win,
		shadow_win = shadow_win,
		buf = buf,
		choices = choices,
		on_close = opts.on_close,
		on_submit = opts.on_submit,
		ns_cursor = ns_cursor,
		old_buf = old_buf,
	}

	-- Setup keymapping for floating window
	vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', '<cmd>lua require"contextmenu".close()<CR>', {noremap = true})
	vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>lua require"contextmenu".submit()<CR>', {noremap = true})

	vim.api.nvim_command("autocmd WinLeave * ++once lua require'contextmenu'.close()")
end

--@private
-- Called when window closes or loses focus via keymapping or autocmd
function M.close()
	if not focused.submitted then
		M.deinit()

		if focused.on_close then
			focused.on_close()
		end

		focused = {}
	end
end

--@private
-- Called when user pressed <CR>
function M.submit()
	local chosen = vim.fn.line(".")

	-- nasty flag to avoid triggering on_close
	focused.submitted = true 

	M.deinit()

	if focused.on_submit then
		focused.on_submit(chosen)
	end

	focused = {}
end

--@private
-- Deinitialize everything
function M.deinit()
	if focused.win and vim.api.nvim_win_is_valid(focused.win) then
		vim.api.nvim_win_close(focused.win, true)
	end

	if focused.shadow_win and vim.api.nvim_win_is_valid(focused.shadow_win) then
		vim.api.nvim_win_close(focused.shadow_win, true)
	end

	M.hide_cursor(focused.old_buf, focused.ns_cursor)
end


--@private
-- Draw cursor as a highlight
function M.display_cursor()
	-- get cursor position
	local _, row, col, _ = unpack(vim.fn.getpos("."))

	-- get next char byte position
	local line = vim.api.nvim_get_current_line()
	local c, _ = vim.str_utfindex(line, col-1)
	local len = vim.str_utfindex(line)
	local next_col
	if c == len then
		next_col = -1
	else
		next_col = vim.str_byteindex(line, c+1)
	end

	-- add hightlight to buffer
	local ns_cursor = vim.api.nvim_buf_add_highlight(0, 0, "TermCursor", row-1, col-1, next_col)
	return ns_cursor
end

--@private
-- Clear cursor highlight
function M.hide_cursor(buf, ns_cursor)
	if ns_cursor then
		vim.api.nvim_buf_clear_namespace(buf, ns_cursor, 0, -1)
	end
end

return M
