// SPDX-License-Identifier: GPL-2.0

//! My Rust kernel module.
//!
//! Built with RustKernelix. Load with `modprobe my_module` and check
//! `dmesg` for output.

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
