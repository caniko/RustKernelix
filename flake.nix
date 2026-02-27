{
  description = "RustKernelix — Framework for out-of-tree Rust Linux kernel modules";

  nixConfig = {
    extra-substituters = ["https://rustkernelix.cachix.org"];
    extra-trusted-public-keys = ["rustkernelix.cachix.org-1:PLACEHOLDER"];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    crane,
  }: let
    lib = nixpkgs.lib;
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = lib.genAttrs supportedSystems;

    mkPkgsRust = system:
      import nixpkgs {
        inherit system;
        overlays = [rust-overlay.overlays.default];
      };
  in {
    lib = {
      # Build an out-of-tree Rust kernel module using Kbuild.
      #
      # The Linux kernel build system handles all Rust compilation — this
      # does NOT use `cargo build`. The derivation wraps `make -C $KDIR`
      # via stdenv.mkDerivation.
      #
      # rust-overlay is used to validate the toolchain version at eval time.
      # The actual build uses the kernel's own rustc from moduleBuildDependencies
      # to guarantee ABI compatibility.
      #
      # Arguments:
      #   kernel         - Kernel package (must have withRust = true)
      #   src            - Path to module source (must contain Kbuild + .rs files)
      #   pname          - Package name
      #   version        - Package version
      #   rustcVersion   - (optional) Expected rustc version; validated at both
      #                    eval time (via rust-overlay) and build time (vs kernel)
      #   extraMakeFlags - (optional) Additional flags passed to make
      #   meta           - (optional) Additional meta attributes
      buildRustKernelModule = args: let
        system = args.kernel.stdenv.hostPlatform.system;
        pkgsRust = mkPkgsRust system;
      in
        import ./lib/builder.nix (args // {inherit pkgsRust lib;});

      # Create a development shell with a Rust toolchain matching the kernel.
      #
      # Uses rust-overlay to pin the exact rustc version so rust-analyzer,
      # clippy, and fmt work correctly against kernel code.
      mkDevShell = {
        system,
        rustcVersion,
      }: let
        pkgs = mkPkgsRust system;
        toolchain = pkgs.rust-bin.stable.${rustcVersion}.default.override {
          extensions = ["rust-src" "rust-analyzer"];
        };
      in
        pkgs.mkShell {
          packages = [
            toolchain
            pkgs.llvmPackages.clang
            pkgs.llvmPackages.llvm
          ];
          RUST_SRC_PATH = "${toolchain}/lib/rustlib/src/rust/library";
        };

      # Build a userspace Rust tool using crane.
      #
      # Use this for companion CLI tools, NOT for kernel modules.
      # Crane handles cargo workspace resolution, incremental compilation,
      # and artifact caching.
      buildUserspaceTool = {
        system,
        src,
        pname,
        version,
        rustcVersion ? null,
      }: let
        pkgs = mkPkgsRust system;
        toolchain =
          if rustcVersion != null
          then pkgs.rust-bin.stable.${rustcVersion}.minimal
          else pkgs.rust-bin.stable.latest.minimal;
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
      in
        craneLib.buildPackage {
          inherit src pname version;
        };
    };

    nixosModules.default = ./modules/kernel-module.nix;

    templates.default = {
      path = ./templates/default;
      description = "Scaffold a new out-of-tree Rust kernel module project";
    };

    formatter = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.alejandra);

    devShells = forAllSystems (system: let
      pkgs = mkPkgsRust system;
    in {
      default = pkgs.mkShell {
        packages = [
          (pkgs.rust-bin.stable.latest.default.override {
            extensions = ["rust-src" "rust-analyzer"];
          })
          pkgs.llvmPackages.clang
          pkgs.llvmPackages.llvm
        ];
      };
    });
  };
}
