#
# Makefile for livecd creation
#

all: create-iso.stamp
	@echo "Now burn your iso and have fun!"

create-rootfs.stamp:
ifeq ($(CONFIG),)
	ln -sf config.dev config
else
	ln -sf config.$(CONFIG) config
endif
	bin/create-rootfs
	touch $@

create-squash.stamp: create-rootfs.stamp
	bin/create-squash
	touch $@

create-iso.stamp: create-squash.stamp
	bin/create-iso
	touch $@

boot: create-iso.stamp
	bin/boot-qemu

clean:
	git clean -x -d -f
