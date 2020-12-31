contextmenu.nvim
----------------

A context menu creation toolkit for Neovim written in Lua.

[![Untitled.png](https://i.postimg.cc/h4xbjysf/Untitled.png)](https://postimg.cc/YjrmDxJH)

### Features

* Easy integration

* Navigation with <kbd>J</kbd> / <kbd>K</kbd>

* Customizable

### Installation

```
Plug 'jbyuki/contextmenu.nvim'
```

For border support:

```
Plug 'nvim-lua/plenary.nvim'
```

### Usage

```
local choices = {"choice 1", choice 2"}
require"contextmenu".open(choices,
	on_submit = function(chosen) 
		print("Final choice " .. choices[chosen])
	end
)
```

### Help

* If you encounter any problems, please feel free to open an Issue

* To my knowledge this kind of functionnality is not present in [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) maybe have something like this merged in the future?
