{
description = "A collection of functions and types for handling Lua config files";
inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"; };
outputs = {nixpkgs, ...}: import ./lib.nix {lib = nixpkgs.lib;};
}
