# SPDX-License-Identifier: GPL-2.0
#
# NixOS module for loading RustKernelix-built kernel modules.
{
  config,
  lib,
  ...
}: let
  cfg = config.rustKernelix;
in {
  options.rustKernelix = {
    modules = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = ''
        List of kernel module packages built with RustKernelix to install.
        Each package is added to {option}`boot.extraModulePackages`.
      '';
    };

    autoload = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        List of module names to load at boot via {option}`boot.kernelModules`.
        These should match the `.ko` file names (without the extension).
      '';
    };
  };

  config = lib.mkIf (cfg.modules != []) {
    boot.extraModulePackages = cfg.modules;
    boot.kernelModules = cfg.autoload;
  };
}
