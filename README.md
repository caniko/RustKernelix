# RustKernelix

**Nix framework for building out-of-tree Rust Linux kernel modules.**

Build, validate, and deploy Rust kernel modules with Nix — using the kernel's
own build system (Kbuild), not cargo.

[![License: GPL-2.0](https://img.shields.io/badge/License-GPL--2.0-blue.svg)](LICENSE)

## Why RustKernelix?

Linux kernel modules written in Rust must be compiled through Kbuild, not
`cargo build`. Kbuild ensures correct compiler flags, bindgen invocations, and
ABI compatibility with the running kernel. RustKernelix wraps this into a
single Nix function call.

**Key features:**

- **Kbuild-native builds** — uses `make -C $KDIR`, not cargo. Correct by construction.
- **ABI-safe** — builds with the kernel's own rustc from `moduleBuildDependencies`.
- **Eval-time validation** — catches rustc version mismatches before the build starts.
- **NixOS module** — wire built modules into `boot.extraModulePackages` declaratively.
- **Dev shell** — rust-analyzer, clippy, and fmt with the exact toolchain your kernel uses.
- **Userspace tool builder** — build companion CLI tools with crane.
- **Flake template** — `nix flake init` to scaffold a new module project in seconds.

## Quick Start

Scaffold a new project:

```bash
nix flake init -t codeberg:caniko/RustKernelix
```

Or add RustKernelix to an existing flake:

```nix
{
  inputs.rustkernelix = {
    url = "codeberg:caniko/RustKernelix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

## Usage

### Building a Kernel Module

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rustkernelix = {
      url = "codeberg:caniko/RustKernelix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, rustkernelix, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    kernel = pkgs.linuxPackages_latest.kernel.override { withRust = true; };
  in {
    packages.${system}.default = rustkernelix.lib.buildRustKernelModule {
      inherit kernel;
      src = ./src;          # Directory with Kbuild + .rs files
      pname = "my-module";
      version = "0.1.0";
    };
  };
}
```

Your `src/` directory needs three files:

**`src/my_module.rs`** — the Rust module:
```rust
// SPDX-License-Identifier: GPL-2.0
use kernel::prelude::*;

module! {
    type: MyModule,
    name: "my_module",
    author: "Your Name",
    description: "My Rust kernel module",
    license: "GPL",
}

struct MyModule;

impl kernel::Module for MyModule {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("my_module: loaded\n");
        Ok(MyModule)
    }
}

impl Drop for MyModule {
    fn drop(&mut self) {
        pr_info!("my_module: unloaded\n");
    }
}
```

**`src/Kbuild`**:
```makefile
obj-m := my_module.o
```

**`src/Makefile`**:
```makefile
KDIR ?= /lib/modules/$(shell uname -r)/build

default:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1

modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 clean
```

Build it:

```bash
nix build
```

### NixOS Module

RustKernelix provides a NixOS module for declarative module loading:

```nix
# In your NixOS configuration:
{
  imports = [ rustkernelix.nixosModules.default ];

  rustKernelix = {
    modules = [ my-module-package ];   # Built with buildRustKernelModule
    autoload = [ "my_module" ];        # Load at boot
  };
}
```

This wires your packages into `boot.extraModulePackages` and module names into
`boot.kernelModules`.

### Development Shell

Get a shell with the exact Rust toolchain your kernel uses:

```nix
devShells.${system}.default = rustkernelix.lib.mkDevShell {
  inherit system;
  rustcVersion = "1.85.0";  # Must match your kernel's Rust version
};
```

Includes rust-analyzer, rust-src, clang, and LLVM.

### Userspace Companion Tools

Build Rust CLI tools that accompany your kernel module (e.g., configuration
utilities, monitoring tools):

```nix
packages.${system}.my-tool = rustkernelix.lib.buildUserspaceTool {
  inherit system;
  src = ./my-tool;
  pname = "my-tool";
  version = "0.1.0";
};
```

Uses [crane](https://github.com/ipetkov/crane) under the hood for incremental
builds and artifact caching.

## Prerequisites

Your kernel must have Rust support enabled. In NixOS:

```nix
boot.kernelPackages = pkgs.linuxPackages_latest.extend (final: prev: {
  kernel = prev.kernel.override { withRust = true; };
});
```

Or override the kernel directly:

```nix
kernel = pkgs.linuxPackages_latest.kernel.override { withRust = true; };
```

The kernel's `CONFIG_RUST=y` must be set, which `withRust = true` handles.

## API Reference

### `lib.buildRustKernelModule`

Build an out-of-tree Rust kernel module using Kbuild.

| Argument | Type | Required | Description |
|---|---|---|---|
| `kernel` | package | yes | Kernel package with `withRust = true` |
| `src` | path | yes | Directory containing Kbuild + `.rs` files |
| `pname` | string | yes | Package name |
| `version` | string | yes | Package version |
| `rustcVersion` | string | no | Expected rustc version; validated at eval time and build time |
| `extraMakeFlags` | list | no | Additional flags passed to Kbuild |
| `meta` | attrs | no | Additional meta attributes |

### `lib.mkDevShell`

Create a development shell with a Rust toolchain matching the kernel.

| Argument | Type | Required | Description |
|---|---|---|---|
| `system` | string | yes | Architecture (e.g., `"x86_64-linux"`) |
| `rustcVersion` | string | yes | Exact rustc version to pin (e.g., `"1.85.0"`) |

### `lib.buildUserspaceTool`

Build a userspace Rust tool using crane. For CLI tools, NOT kernel modules.

| Argument | Type | Required | Description |
|---|---|---|---|
| `system` | string | yes | Architecture |
| `src` | path | yes | Cargo project source |
| `pname` | string | yes | Package name |
| `version` | string | yes | Package version |
| `rustcVersion` | string | no | Rust toolchain version (defaults to latest stable) |

### `nixosModules.default`

NixOS module for loading built kernel modules.

| Option | Type | Default | Description |
|---|---|---|---|
| `rustKernelix.modules` | list of packages | `[]` | Module packages for `boot.extraModulePackages` |
| `rustKernelix.autoload` | list of strings | `[]` | Module names for `boot.kernelModules` |

## Binary Cache

RustKernelix publishes pre-built artifacts to Cachix. Add to your NixOS
configuration or `~/.config/nix/nix.conf`:

```
extra-substituters = https://rustkernelix.cachix.org
extra-trusted-public-keys = rustkernelix.cachix.org-1:PLACEHOLDER
```

If you use RustKernelix as a flake input, the `nixConfig` block will prompt you
to trust the cache automatically.

## Troubleshooting

### "kernel does not have Rust support (withRust != true)"

Your kernel package was not built with Rust. Override it:

```nix
kernel = pkgs.linuxPackages_latest.kernel.override { withRust = true; };
```

### "rustc not found in PATH"

The kernel's `moduleBuildDependencies` does not include the Rust toolchain.
This means `CONFIG_RUST` was not enabled during the kernel build. Rebuild
the kernel with `withRust = true`.

### "rustc version mismatch"

The `rustcVersion` you specified does not match the kernel's bundled rustc.
Either:
- Update `rustcVersion` to match (check `nix eval --raw '.#kernel.modDirVersion'`)
- Rebuild the kernel with the expected Rust version

### "rust-overlay does not provide rustc X.Y.Z"

The version string is invalid or not yet available in rust-overlay. Check
[rust-overlay releases](https://github.com/oxalica/rust-overlay) for
supported versions.

## Examples

See [`examples/hello-rust-mod/`](examples/hello-rust-mod/) for a minimal
working kernel module.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, formatting,
and submission guidelines.

## License

GPL-2.0-only. See [LICENSE](LICENSE).

Kernel modules must be GPL-licensed to access kernel symbols. This applies to
both the framework and all modules built with it.
