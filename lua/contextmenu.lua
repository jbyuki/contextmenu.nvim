--
-- Plugin: contextmenu.nvim 
-- Description: A simple to use lua library to have contextual menu in 
--              your Neovim plugin
-- 
-- Usage:
-- 		local choices = {"choice 1", choice 2"}
-- 		require"contextmenu".open(choices, {
-- 			callback = function(chosen) 
-- 				print("Final choice " .. choices[chosen])
-- 			end
-- 		})
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
		width = math.max(width, opts.padding[4] + w + opts.padding[2])
	end

	if opts.maxwidth then
		width = math.min(width, opts.maxwidth)
	end

	-- Compute height
	local height = #choices

	if opts.maxheight then
		height = math.min(height, opts.maxheight)
	end

	-- Determine float anchor
	local anchor
	if opts.pos == "topleft" then anchor = "NW"
	elseif opts.pos == "topright" then anchor = "NE"
	elseif opts.pos == "botleft" then anchor = "SW"
	elseif opts.pos == "botright" then anchor = "SE"
	end

	-- Determine float position
	-- Currently does not mix between cursor relative
	-- and editor relative positions
	local relative, col, row

	if string.match(opts.line, "cursor") then
		relative = "cursor"
		row = M.parse_line_and_col(opts.line)
	else
		relative = "editor"
		row = opts.line
	end

	if string.match(opts.col, "cursor") then
		col = M.parse_line_and_col(opts.col)
	else
		col = opts.line
	end

	-- Create float window
	local win_opts = {
		relative =  relative,
		anchor = anchor,
		width =  width, 
		height = height, 
		col = col + opts.border,
		row = row + opts.border, 
		style =  'minimal',
	}

	local border_opts = {
		title = opts.title,
		width = opts.border,
		top      = opts.borderchars[1],
		right    = opts.borderchars[2],
		bot      = opts.borderchars[3],
		left     = opts.borderchars[4],
		topleft  = opts.borderchars[5],
		topright = opts.borderchars[6],
		botright = opts.borderchars[7],
		botleft  = opts.borderchars[8],
	}

	-- use borders if plenary is installed
	local win = vim.api.nvim_open_win(buf, false, win_opts)
	pcall(function()
		local Border = require("plenary.window.border")
		Border:new(buf, win, win_opts, border_opts)
	end)

	vim.api.nvim_win_set_option(win, "cursorline", true)
	vim.api.nvim_win_set_option(win, "winhl", "CursorLine:" .. opts.highlight)
	vim.api.nvim_set_current_win(win)

	return buf, win
end

--@private
-- Adds padding on the left to every elements
-- according to opts.padding[2] (right)
local function pad_text(choices, opts)
	for i=1,#choices do
		for _=1,opts.padding[2] do
			choices[i] = " " .. choices[i]
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
function M.open(choices, opts)
	vim.validate {
		choices = {choices, "t"},
		opts = {opts, "t", true},
	}

	opts = opts or {}

	local NA = function(arg) return not arg end 

	vim.validate {
		["opts.line"] = { opts.line, 
		function(arg) 
			return not arg or type(arg) == "number" or type(arg) == "string"
		end, "opts.line must be a number, a string or nil" },

		["opts.col"] = { opts.col, 
		function(arg) 
			return not arg or type(arg) == "number" or type(arg) == "string"
		end, "opts.col must be a number, a string or nil" },

		["opts.pos"] = { opts.pos, "s", true },

		["opts.maxheight"] = { opts.maxheight, "n", true },
		["opts.minheight"] = { opts.minheight, "n", true },
		["opts.maxwidth"] = { opts.maxwidth, "n", true },
		["opts.minwidth"] = { opts.minwidth, "n", true },
		["opts.title"] = { opts.title, "s", true },
		["opts.highlight"] = { opts.hightlight, "s", true },
		["opts.padding"] = { opts.padding, "t", true },
		["opts.border"] = { opts.border, "n", true },
		["opts.borderchars"] = { opts.borderchars, "t", true },
		["opts.time"] = { opts.time, "n", true },
		["opts.callback"] = { opts.callback, "f", true },

		-- not supported atm
		["opts.firstline"] = { opts.firstline, NA, true },
		["opts.wrap"] = { opts.wrap, NA, true },
		["opts.borderhighlight"] = { opts.borderhighlight, NA, "not supported" },
		["opts.posinvert"] = { opts.posinvert, NA, "not supported!" },
		["opts.textprop"] = { opts.textprop, NA, "not supported!" },
		["opts.fixed"] = { opts.fixed, NA, "not supported!" },
		["opts.flip"] = { opts.flip, NA, "not supported!" },
		["opts.hidden"] = { opts.hidden, NA, "not supported!" },
		["opts.tabpage"] = { opts.tabpage, NA, "not supported!" },
		["opts.drag"] = { opts.drag, NA, "not supported!" },
		["opts.resize"] = { opts.resize, NA, "not supported!" },
		["opts.close"] = { opts.close, NA, "not supported!" },
		["opts.scrollbar"] = { opts.scrollbar, NA, "not supported!" },
		["opts.scrollbarhighlight"] = { opts.scrollbarhighlight, NA, "not supported!" },
		["opts.thumbhighlight"] = { opts.thumbhighlight, NA, "not supported!" },
		["opts.zindex"] = { opts.zindex, NA, "not supported!" },
		["opts.mask"] = { opts.mask, NA, "not supported!" },
		["opts.moved"] = { opts.moved, NA, "not supported!" },
		["opts.cursorline"] = { opts.cursorline, NA, "not supported!" },
		["opts.filter"] = { opts.filter, NA, "not supported!" },
		["opts.mapping"] = { opts.mapping, NA, "not supported!" },
		["opts.filtermode"] = { opts.filtermode, NA, "not supported!" },
	}

	if padding and (padding[1] ~= 0 or padding[3] ~= 0) then
		error("top/bot border not supported!")
	end

	-- set default settings
	opts.padding = opts.padding or { 0, 1, 0, 1}
	opts.borderchars = M.fill_borderchars(borderchars)
	opts.border = opts.border or 1
	opts.highlight = opts.highlight or "TermCursor"
	opts.title = opts.title or ""
	opts.line = opts.line or "cursor+1"
	opts.col = opts.col or "cursor+1"

	-- Leave a highlight where the cursor was
	local old_buf = vim.api.nvim_get_current_buf()
	local ns_cursor = M.display_cursor()

	-- Display floating with text
	local buf, win = create_float_win(choices, opts)

	pad_text(choices, opts)
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, choices)

	focused = {
		win = win,
		buf = buf,
		choices = choices,
		callback = opts.callback,
		ns_cursor = ns_cursor,
		old_buf = old_buf,
	}

	-- Setup keymapping for floating window
	vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', '<cmd>lua require"contextmenu".close()<CR>', {noremap = true})
	vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>lua require"contextmenu".submit()<CR>', {noremap = true})

	vim.api.nvim_command("autocmd WinLeave * ++once lua require'contextmenu'.close()")
end

--@private
-- Fills the borderchars array completly
-- according to what's received
function M.fill_borderchars(borderchars)
	if not borderchars then
		borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰'}
	elseif #borderchars == 1 then
		local a = borderchars[1]
		borderchars = { a, a, a, a,    a, a, a, a }
	elseif #borderchars == 2 then
		local b = borderchars[1]
		local c = borderchars[2]
		borderchars = { b, b, b, b,    c, c, c, c }
	elseif #borderchars == 4 then
		local a = borderchars[1]
		local b = borderchars[2]
		local c = borderchars[3]
		local d = borderchars[4]
		borderchars = { a, b, c, d,    '+', '+', '+', '+' }
	end
	return borderchars
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

	if focused.callback then
		focused.callback(chosen)
	end

	focused = {}
end

--@private
-- Deinitialize everything
function M.deinit()
	if focused.win and vim.api.nvim_win_is_valid(focused.win) then
		vim.api.nvim_win_close(focused.win, true)
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

--@private
-- Extract relative number after "cursor" in row and
-- line arguments
function M.parse_line_and_col(str)
	local rel = string.match(str, "cursor([+%-]%d+)")
	rel = tonumber(rel)
	return rel
end

return M
