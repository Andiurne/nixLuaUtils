# nixLuaUtils
A Nix flake providing a library of utility functions for creating Lua configuration files with an intuitive user syntax.

## Userspace Utilities

### mkLuaText
A shorthand lambda for wrapping a Nix string in a luaText attrs.

## Module Utilities

### maybeLuaText
A type for declaring options which may or may not be literal Lua text.
For example, if `options.background_color` is of type maybeLuaText, then
`config.value = "123"` -> {lua} `value = "123"`, while
`config.value.lua = "getValue()"` -> {lua} `value = getValue()` can be neatly
handled with the use of parseMaybeLuaText.

### luaValue
`nullOr oneOf` enumerating types supported by interpretLuaValue, intended
to capture all basic Lua data types.

### interpretLuaValue
A formatting lambda which turns `input` of type:
- `str` into `"${str}"` (adds quotation marks for use as Lua string)
- `bool` into `true` or `false` appropriately
- `number` into its `toString` form, for use in text
- `attrsOf luaValue` into a Nix string-keyed table, i.e. `{key = "value";} -> {["key"] = "value", ...}`
- `listOf luaValue` into an anonymous table, i.e. `{a, b, c}`
- `maybeLuaText` into its `parseMaybeLuaText` value, i.e. a quoted or unquoted string
A `null` input is converted into `nil`

### luaFunctionDeclaration
A submodule with options `name`, `parameters`, and `body`.
Defaults to, respectively,
- the name of the submodule
- []
- ''''

### mkLuaFunctionText
Produces the text for a lua function declaration.
Takes an attrs with at least `body` declared.
May be used neatly with a `luaFunctionDeclaration` "func" as
`text = mkLuaFunctionText func`.

### mkLuaVariableText
`{name, value} -> ''${name} = ${value}''`

### attrsToKeyedTable
Assumes values in `attrs` are parseable by `interpretLuaValue`,
and names are Nix strings (no escaped quotes) to be used as keys.
For example,
```
attrs = {color.lua = "0xff0000"; text = "hello";};
attrsToKeyedTable attrs => ''{["color"] = 0xff0000, ["text"] = "hello"}''
```

### attrsToRawTable
As attrsToKeyedTable, but keys are treated as raw lua.
Recurses using itself for non-luaText attrs.

### listToAnonTable
A lambda as `["hello" 12 {lua = "0x00ff00";}] -> {"hello", 12, 0x00ff00}`.

### mkLuaFunctionCall
Turns an attrs representation into a lua function call, where
- `path` is the path of the function, as either
    - a list of fields to be separated by "."
    - a `maybeLuaText`, which is unquoted regardless
- `argList` is a ordered list of arguments to supply to the function
