#
# Makefile for livecd creation
#

all: create-iso
	@echo "Now burn your iso and have fun!"

create-rootfs: create-rootfs.stamp
create-rootfs.stamp:
	./create-rootfs.sh
	touch $@

create-squash: create-squash.stamp
create-squash.stamp: create-rootfs
	./create-squash.sh
	touch $@

create-iso: create-iso.stamp
create-iso.stamp: create-squash
	./create-iso.sh
	touch $@

boot: create-iso
	./boot-qemu.sh

clean:
	git clean -x -d -f
