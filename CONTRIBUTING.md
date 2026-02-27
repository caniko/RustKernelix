# Contributing to RustKernelix

## Development Setup

Enter the development shell:

```bash
nix develop
```

This provides Rust (stable, latest), rust-analyzer, clang, and LLVM.

## Code Formatting

All Nix files are formatted with [alejandra](https://github.com/kamadorueda/alejandra):

```bash
nix fmt
```

Run this before committing. CI will reject unformatted code.

## Testing Changes

Build the example module to verify your changes work:

```bash
nix build .#example-hello-rust-mod
```

Note: this requires a kernel with Rust support, which may take a while to build
from source if not cached.

Run all checks:

```bash
nix flake check -L
```

## Project Structure

```
flake.nix              # Flake definition with all outputs
lib/builder.nix        # Core derivation logic for Kbuild modules
modules/               # NixOS modules
  kernel-module.nix    # Module for loading built kernel modules
templates/default/     # Flake template for `nix flake init`
examples/              # Example kernel modules
  hello-rust-mod/      # Minimal "hello world" module
```

## Submitting Changes

1. Fork the repository on Codeberg
2. Create a feature branch
3. Make your changes and ensure `nix flake check` passes
4. Submit a pull request with a clear description of the change

## License

All contributions must be licensed under GPL-2.0-only, matching the project license.
Kernel module code requires GPL licensing for access to kernel symbols.
