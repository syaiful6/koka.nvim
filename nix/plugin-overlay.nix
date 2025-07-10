{
  self,
  name,
}: final: prev: let
  lib = final.lib;

  kokanvim-luaPackage-override = luaself: luaprev: {
    kokanvim = luaself.callPackage ({
      luaOlder,
      buildLuarocksPackage,
    }:
      buildLuarocksPackage {
        pname = name;
        version = "scm-1";
        knownRockspec = "${self}/kokanvim-scm-1.rockspec";
        src = self;
        disabled = luaOlder "5.1";
      }) {};
  };

  lua5_1 = prev.lua5_1.override {
    packageOverrides = kokanvim-luaPackage-override;
  };
  luajit = prev.luajit.override {
    packageOverrides = kokanvim-luaPackage-override;
  };

  lua51Packages = final.lua5_1.pkgs;
  luajitPackages = final.luajit.pkgs;
in {
  inherit
    lua5_1
    lua51Packages
    luajit
    luajitPackages
    ;

  vimPlugins =
    prev.vimPlugins
    // {
      kokanvim = final.neovimUtils.buildNeovimPlugin {
        luaAttr = final.luajitPackages.kokanvim;
      };
    };

  inherit (final.vimPlugins) kokanvim;
  kokanvim-dev = final.vimPlugins.kokanvim;

  codelldb = final.vscode-extensions.vadimcn.vscode-lldb.adapter;
}
