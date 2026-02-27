# SPDX-License-Identifier: GPL-2.0
{
  description = "My Rust kernel module — built with RustKernelix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rustkernelix = {
      url = "codeberg:caniko/RustKernelix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    rustkernelix,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};

    # Your kernel — must have Rust support enabled.
    # Example: use the default kernel with withRust = true
    kernel = pkgs.linuxPackages_latest.kernel.override {withRust = true;};
  in {
    packages.${system}.default = rustkernelix.lib.buildRustKernelModule {
      inherit kernel;
      src = ./src;
      pname = "my-module";
      version = "0.1.0";
    };

    # Optional: NixOS module for auto-loading
    nixosModules.default = {
      imports = [rustkernelix.nixosModules.default];
      rustKernelix = {
        modules = [self.packages.${system}.default];
        autoload = ["my_module"];
      };
    };

    devShells.${system}.default = rustkernelix.lib.mkDevShell {
      inherit system;
      # Match your kernel's rustc version:
      rustcVersion = "1.85.0";
    };
  };
}
