{ callPackage }:

{
  dist = callPackage ./dist.nix { };
  langpack = callPackage ./langpack.nix { };
}

