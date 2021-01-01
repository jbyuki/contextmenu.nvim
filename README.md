contextmenu.nvim
----------------

A context menu creation toolkit for Neovim written in Lua.

Similar to [popup_menu()](https://vimhelp.org/popup.txt.html#popup_menu%28%29) but with floating window.

[![Untitled.png](https://i.postimg.cc/h4xbjysf/Untitled.png)](https://postimg.cc/YjrmDxJH)

### Features

* Easy integration

* Navigation with <kbd>J</kbd> / <kbd>K</kbd>

* Customizable

### Installation

```vim
Plug 'jbyuki/contextmenu.nvim'
```

For border support:

```vim
Plug 'nvim-lua/plenary.nvim'
```

### Usage

```lua
local choices = {"choice 1", choice 2"}
require"contextmenu".open(choices, {
	callback = function(chosen) 
		print("Final choice " .. choices[chosen])
	end
})
```

For options see [popup-usage](https://vimhelp.org/popup.txt.html#popup-usage).
Arguments are (very) partially implemented.

### Help

* If you encounter any problems, please feel free to open an Issue

* To my knowledge this kind of functionnality is not present in [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) maybe have something like this merged in the future?
