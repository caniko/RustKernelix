// SPDX-License-Identifier: GPL-2.0

//! Minimal Rust kernel module example.
//!
//! Demonstrates the basic structure of an out-of-tree Rust kernel module
//! built with RustKernelix. Load with `modprobe hello_rust_mod` and check
//! `dmesg` for output.

use kernel::prelude::*;

module! {
    type: HelloRustMod,
    name: "hello_rust_mod",
    author: "RustKernelix",
    description: "A minimal Rust kernel module example",
    license: "GPL",
}

struct HelloRustMod;

impl kernel::Module for HelloRustMod {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("Hello from Rust kernel module!\n");
        Ok(HelloRustMod)
    }
}

impl Drop for HelloRustMod {
    fn drop(&mut self) {
        pr_info!("Goodbye from Rust kernel module!\n");
    }
}
