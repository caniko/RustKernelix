# RustKernelix vision

RustKernelix is a Nix framework for building out-of-tree Rust Linux kernel
modules. It wraps the kernel's own build system in a single Nix function, adds a
matching development shell, a NixOS module for loading built modules, a flake
template, and a crane-based builder for companion userspace tools. It is aimed
at people who want to write a Rust kernel module and have Nix build, validate,
and deploy it.

## Problem

Rust code in the kernel is compiled through Kbuild, not `cargo build`. Building
a module out of tree means driving `make -C $KDIR` with the kernel's own
toolchain, matching its rustc exactly, and generating the target specification
and bindings the kernel expects. Each project that does this by hand re-derives
flag filtering, output-directory handling, and ABI checks, and gets them subtly
wrong.

## Principles

- Kbuild-native, not cargo: the builder runs `make -C $KDIR` so compiler flags,
  bindgen invocations, and ABI compatibility come from the kernel itself.
- ABI-safe by construction: modules build with the kernel's own rustc from
  `moduleBuildDependencies`, not with a separately chosen compiler.
- Fail early: a `rustcVersion` mismatch fails the build's pre-build check before
  any module compilation, and a kernel without Rust support is rejected at
  evaluation time.
- Deployment is declarative: the NixOS module wires packages into
  `boot.extraModulePackages` and module names into `boot.kernelModules`.
- The dev shell matches the build: rust-analyzer, clippy, and fmt come from the
  same pinned toolchain the kernel uses.
- Licensing is a hard constraint: GPL-2.0-only, because modules must be
  GPL-licensed to access kernel symbols. This applies to the framework and to
  every module built with it.
- Userspace tools are a separate concern: `buildUserspaceTool` uses crane, and
  the API reference states it is for CLI tools, not kernel modules.

## Scope

- `lib.buildRustKernelModule`: out-of-tree Kbuild module derivation with
  `pname`, `version`, optional `rustcVersion` validation, extra make flags, and
  meta.
- `lib.mkDevShell`: a development shell pinned to an exact rustc version.
- `lib.buildUserspaceTool`: crane-based userspace companion binaries.
- `nixosModules.default`: `rustKernelix.modules` and `rustKernelix.autoload`.
- A flake template for `nix flake init`, plus a minimal
  `examples/hello-rust-mod`.

## Non-goals

- It is not a crate catalog or a module registry; it builds what a project
  points it at.
- It does not build kernels. It requires a kernel with `CONFIG_RUST=y`
  (`withRust = true`) and reports a clear error when that is missing.

## Direction

Recent commits are all in-tree build correctness for the out-of-tree case:
filtering kernel-internal flags out of `makeFlags`, generating `target.json`
when the kernel development tree lacks it, copying a writable `Makefile` into
the KDIR overlay instead of symlinking, and pinning `--edition 2021` for
`generate_rust_target.rs`. The current head is explicitly a work-in-progress
`KBUILD_OUTPUT` fix. No separate roadmap is checked in.

## Place in the fleet

No canix consumer was found. Canix records the project only in the atlas
`simit-updater` registry.
