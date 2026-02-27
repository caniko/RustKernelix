# SPDX-License-Identifier: GPL-2.0
#
# Core derivation logic for building out-of-tree Rust kernel modules.
#
# This uses Kbuild (the Linux kernel build system) to compile the module.
# Do NOT use `cargo build` for .ko files — the kernel's Kbuild handles
# Rust compilation with the correct flags, bindgen invocations, and ABI
# compatibility guarantees.
#
# The kernel's own rustc (from moduleBuildDependencies) is used for the
# actual build. rust-overlay is only used for eval-time version validation.
{
  # Required
  kernel, # Kernel package (must have withRust = true)
  src, # Path to module source (must contain Kbuild + .rs files)
  pname, # Package name
  version, # Package version
  # Internal (injected by flake.nix)
  pkgsRust, # nixpkgs with rust-overlay applied
  lib, # nixpkgs.lib
  # Optional
  rustcVersion ? null, # Expected rustc version (e.g., "1.85.0")
  extraMakeFlags ? [], # Additional Kbuild flags
  meta ? {}, # Additional meta attributes
}: let
  hasRust = kernel ? withRust && kernel.withRust;

  kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  # kernel.makeFlags includes flags intended for the kernel's own build
  # (e.g., O=$(buildRoot), --eval=undefine modules) that break out-of-tree
  # module builds. Filter to only keep variable assignments (NAME=VALUE)
  # which carry the toolchain paths, ARCH, CROSS_COMPILE, etc.
  moduleMakeFlags = builtins.filter (flag:
    !(lib.hasPrefix "O=" flag) && !(lib.hasPrefix "--eval=" flag)
  ) kernel.makeFlags;

  # Eval-time validation: if rustcVersion is specified, verify rust-overlay
  # knows about it. This catches typos and unsupported versions immediately
  # rather than at build time.
  _rustToolchainCheck =
    if rustcVersion != null
    then
      pkgsRust.rust-bin.stable.${rustcVersion}.minimal
      or (throw "RustKernelix: rust-overlay does not provide rustc ${rustcVersion}")
    else null;
in
  assert lib.assertMsg hasRust
  "RustKernelix: kernel '${kernel.name}' does not have Rust support (withRust != true)";
    kernel.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = kernel.moduleBuildDependencies;

      makeFlags =
        moduleMakeFlags
        ++ [
          "KDIR=${kdir}"
          "LLVM=1"
        ]
        ++ extraMakeFlags;

      preBuild = ''
        echo "RustKernelix: building '${pname}' v${version} for kernel ${kernel.modDirVersion}"

        if ! command -v rustc &> /dev/null; then
          echo >&2 "RustKernelix: ERROR — rustc not found in PATH"
          echo >&2 "  The kernel's moduleBuildDependencies does not include the Rust toolchain."
          echo >&2 "  Kernel: ${kernel.name}"
          echo >&2 "  Ensure the kernel was built with CONFIG_RUST=y."
          exit 1
        fi

        RUSTC_VER=$(rustc --version | sed -n 's/rustc \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
        echo "RustKernelix: rustc $RUSTC_VER (from kernel build deps)"

        ${lib.optionalString (rustcVersion != null) ''
          if [ "$RUSTC_VER" != "${rustcVersion}" ]; then
            echo >&2 ""
            echo >&2 "RustKernelix: ERROR — rustc version mismatch!"
            echo >&2 "  Expected: ${rustcVersion} (rustcVersion argument)"
            echo >&2 "  Found:    $RUSTC_VER (kernel.moduleBuildDependencies)"
            echo >&2 "  Kernel:   ${kernel.name}"
            echo >&2 ""
            echo >&2 "  Either update rustcVersion to match the kernel's toolchain,"
            echo >&2 "  or rebuild the kernel with the expected Rust version."
            exit 1
          fi
        ''}

        BINDGEN_VER=$(bindgen --version 2>/dev/null | sed -n 's/bindgen \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
        echo "RustKernelix: bindgen ''${BINDGEN_VER:-not found}"
      '';

      installFlags = ["INSTALL_MOD_PATH=${placeholder "out"}"];
      installTargets = ["modules_install"];

      meta =
        {
          broken = !hasRust;
          platforms = lib.platforms.linux;
          license = lib.licenses.gpl2Only;
        }
        // meta;
    }
