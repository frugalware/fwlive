#!/bin/bash -xe

CHROOTDIR="$PWD/rootfs"

if [ "`id -u`" != 0 ]; then
	echo "Not root"
	exit 1
fi

chroot $CHROOTDIR sh -c 'echo "root:fwlive" | chpasswd'
rm -f rootfs.img
dd if=/dev/zero of=rootfs.img bs=1M count=1024
mkfs.ext4 -F rootfs.img
loop=$(mktemp -d)
mount -o loop rootfs.img $loop
cp -a $CHROOTDIR/* $loop
df -h $loop
umount $loop
rmdir $loop

# TODO see later if this reduces size
#e2fsck -f rootfs.img
#resize2fs rootfs.img -M

mkdir -p squashfs-root/LiveOS
mv rootfs.img squashfs-root/LiveOS
# TODO can be xz
rm -f squashfs.img
mksquashfs squashfs-root squashfs.img -comp gzip
