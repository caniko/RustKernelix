# SPDX-License-Identifier: GPL-2.0

KDIR ?= /lib/modules/$(shell uname -r)/build

default:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1

modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 clean
