{lib, ...}: let
                inherit (lib)
                        isBool
                        boolToString
                        types
                        mkOption
                        mkEnableOption
                        mapAttrsToList
                        ;

                mkDisableOption = name: (mkOption{
                        type = types.bool;
                        default = true;
                        description = "Whether to disable ${name}";
                });


                addIndent = lines: "  " + addIndentExceptFirst lines;
                addIndentExceptFirst = lines: builtins.replaceStrings ["\n"] ["\n  "] lines;
                addQuotes = text: ''"${text}"'';

        in rec {
                /*
                This type is meant to be used as follows:
                As an example, assume some program with lua configuration
                requires a value to be set through a field. It can either be
                text, or a lua function call that *returns* text, say foo.getText()
                Then, if the option is of type `either str luaText`,
                `option = "normal text"` -> `lua.field = "normal text"`
                while `option.lua = "foo.getText()"` -> `lua.field = foo.getText()`

                maybeLuaText is shorthand for `either str luaText`
                */
                luaText = with types; addCheck (attrsOf anything) (attrs: attrs ? lua);
                mkLuaText = nixString: {lua = nixString;};

                maybeLuaText = with types; either str luaText;
                hasLuaText = value: builtins.isAttrs value && value ? lua;
                isTable = value: builtins.isAttrs value && !(hasLuaText value);
                getLuaText = attrs: attrs.lua;

                # Takes in a maybeLuaText instance,
                # returns the Nix string to be used in text output.
                parseMaybeLuaText = input:
                if builtins.isAttrs input
                        then getLuaText input
                else input;

                /* Takes in an instance of either:
                - A string
                - A boolean
                - A number
                - An attribute set
                - A listOf luaValue
                - a maybeLuaText (all other lua types, including nil)

                and produces the literal Lua representation of them
                as text.
                */
                interpretLuaValue = input:
                if !(luaValue.check input)
                        then throw "attempting to interpret unsupported type"
                else if isNull input
                        then "nil"
                else if builtins.isList input
                        then listToAnonTable (map interpretLuaValue input)
                else if builtins.isAttrs input
                        # luaText input
                        then if hasLuaText input
                                then getLuaText input

                                # other attrs (interpreted as table)
                                # will recurse by design
                                else attrsToTable { attrs = input; raw = false; inline = true; }
                else if builtins.isString input
                        then addQuotes input
                else if isBool input
                        then boolToString input
                # Must be a number
                else toString input;

                luaValue = with types; nullOr (oneOf [
                        str
                        bool
                        number
                        (attrsOf luaValue)
                        (listOf luaValue)
                        maybeLuaText
                ]);


                luaFunctionDeclaration = with types; submodule({name, ...}:{options =
                {
                        name = mkOption {
                                type = singleLineStr;
                                default = name;
                                description = ''
                                Name of the local lua function to be declared.
                                '';
                        };

                        parameters = mkOption {
                                type = listOf singleLineStr;
                                default = [];
                                description = ''
                                A list of names of function parameters to declare.
                                '';
                        };

                        body = mkOption {
                                type = lines;
                                default = '''';
                                description = ''
                                The function body as a multiline string.
                                '';
                        };
                };});
                mkLuaFunctionText = {name ? "", parameters ? [], body}: ''
                function ${name} (${builtins.concatStringsSep ", " parameters})
                ${addIndent body}
                end
                '';

                mkLuaVariableText = {name, value}: ''${name} = ${value}'';

                /* Assumes values in the attrs are parseable by interpretLuaValue,
                and keys are strings to be surrounded
                in [""]. So,
                `attrsToConvert = {color.lua = "0xff0000"; text = "hello";}`
                ->
                `{["color"] = 0xff0000, ["text"] = "hello" }`

                To use non-string keys, use attrsToRawTable, which will use
                the literal nix strings.
                */
                attrsToTable = {attrs, raw ? true, inline ? true}:
                if raw
                then if inline then attrsToInlineTable {inherit attrs raw;} else attrsToRawTable attrs
                else if inline then attrsToInlineTable {inherit attrs raw;} else attrsToKeyedTable attrs
                ;

                attrsToInlineTable = {attrs, raw ? true}:
                let
                  recurse = value: if isTable value
                                then attrsToInlineTable value
                                else interpretLuaValue value;
                  table = builtins.concatStringsSep ", " (
                        mapAttrsToList (key: value:
                                if isRaw then "${key} = ${recurse value}"
                                        else ''["${key}"] = ${recurse value}''
                                )
                        attrs
                        );
                in "{ ${table} }";

                attrsToKeyedTable = attrs:
                ''
                {
                  ${builtins.concatStringsSep ",\n  "
                        (mapAttrsToList (key: value:
                        ''["${key}"] = ${if isTable value
                                          then addIndentExceptFirst (attrsToKeyedTable value)
                                          else interpretLuaValue value
                                        }''
                        ) attrs)
                }
                }'';

                attrsToRawTable = attrs:
                ''
                {
                  ${builtins.concatStringsSep ",\n  "
                        (mapAttrsToList (key: value:
                        ''${key} = ${
                        if isTable value
                                then addIndentExceptFirst (attrsToRawTable value)
                                else interpretLuaValue value}''
                        ) attrs)}
                }'';

                listToAnonTable = list: "{${builtins.concatStringsSep ", " list}}";

                /* Formatter for a function call
                Path is an ordered list s.t.
                `swayimg.viewer.set_window_background()` has path
                `["swayimg" "viewer" "set_window_background"]`
                */
                mkLuaFunctionCall = {path, argList ? []}:
                let
                pathText = if hasLuaText path
                                then getLuaText path
                        else if builtins.isList path
                                then builtins.concatStringsSep "." path
                        else path;
                in
                "${pathText}(${builtins.concatStringsSep ", " argList})";
}
