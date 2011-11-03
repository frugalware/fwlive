#
# Makefile for livecd creation
#

all: create-iso
	@echo "Now burn your iso and have fun!"

.PHONY: create-rootfs create-squash create-iso boot clean

create-rootfs: create-rootfs.stamp
create-rootfs.stamp:
	bin/create-rootfs
	touch $@

create-squash: create-squash.stamp create-rootfs
create-squash.stamp:
	bin/create-squash
	touch $@

create-iso: create-iso.stamp create-squash
create-iso.stamp:
	bin/create-iso
	touch $@

boot: create-iso
	bin/boot-qemu

clean:
	git clean -x -d -f
