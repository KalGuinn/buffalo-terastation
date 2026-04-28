# Buffalo TeraStation ARM64 Kernel Build
# Native arm64 build on Apple Silicon (no cross-compiler needed)

ARCH         := arm64
CROSS_COMPILE :=
KBUILD_OUTPUT := out
NPROC        := $(shell nproc)

KERNEL_DIR   := kernel/linux
ROOTFS_DIR   := rootfs
ROOTFS_IMG   := $(KBUILD_OUTPUT)/rootfs.squashfs
INITRD_IMG   := $(KBUILD_OUTPUT)/initrd.img
UIMAGE       := $(KBUILD_OUTPUT)/uImage

KERNEL_ARGS  := ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) O=$(abspath $(KBUILD_OUTPUT))

export ARCH CROSS_COMPILE KBUILD_OUTPUT

.PHONY: defconfig menuconfig kernel dtbs modules modules_install \
        rootfs initrd uimage clean help

## defconfig: apply default kernel config
defconfig:
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_ARGS) defconfig

## menuconfig: interactive kernel configuration
menuconfig:
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_ARGS) menuconfig

## kernel: build Image (uncompressed arm64 kernel)
kernel:
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_ARGS) -j$(NPROC) Image

## dtbs: build device tree blobs
dtbs:
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_ARGS) -j$(NPROC) dtbs

## modules: build loadable kernel modules
modules:
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_ARGS) -j$(NPROC) modules

## modules_install: install modules to KBUILD_OUTPUT/modules
modules_install: modules
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_ARGS) \
		INSTALL_MOD_PATH=$(abspath $(KBUILD_OUTPUT))/modules \
		modules_install

## rootfs: pack rootfs directory into squashfs image
rootfs:
	mksquashfs $(ROOTFS_DIR) $(ROOTFS_IMG) -noappend -comp xz

## initrd: create gzipped cpio initramfs
initrd:
	cd $(ROOTFS_DIR) && find . | cpio -o -H newc | gzip > $(abspath $(INITRD_IMG))

## uimage: wrap Image with U-Boot header via mkimage
uimage: kernel
	mkimage -A arm64 -O linux -T kernel -C none \
		-a 0x00080000 -e 0x00080000 \
		-n "TeraStation Kernel" \
		-d $(KBUILD_OUTPUT)/arch/arm64/boot/Image $(UIMAGE)

## clean: remove build output directory
clean:
	rm -rf $(KBUILD_OUTPUT)

## help: show available targets
help:
	@echo "Buffalo TeraStation ARM64 Kernel Build"
	@echo ""
	@echo "Targets:"
	@echo "  defconfig        Apply default kernel config"
	@echo "  menuconfig       Interactive kernel configuration"
	@echo "  kernel           Build Image (arm64 kernel)"
	@echo "  dtbs             Build device tree blobs"
	@echo "  modules          Build loadable kernel modules"
	@echo "  modules_install  Install modules to out/modules/"
	@echo "  rootfs           Pack rootfs/ into squashfs image"
	@echo "  initrd           Create gzipped cpio initramfs from rootfs/"
	@echo "  uimage           Wrap kernel Image with U-Boot header"
	@echo "  clean            Remove build output directory"
	@echo "  help             Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  ARCH=$(ARCH)  CROSS_COMPILE=$(CROSS_COMPILE)"
	@echo "  KBUILD_OUTPUT=$(KBUILD_OUTPUT)  NPROC=$(NPROC)"
