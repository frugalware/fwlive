#!/bin/bash -xe

. $PWD/config 

if [ "`id -u`" != 0 ]; then
	echo "Not root"
	exit 1
fi

## Password root
chroot $CHROOTDIR sh -c 'echo "root:fwlive" | chpasswd'
## file /etc/profile.d/lang.sh
echo "export LANG=$FWLIVELANG" >$CHROOTDIR/etc/profile.d/lang.sh
echo "export LC_ALL=\$LANG" >> $CHROOTDIR/etc/profile.d/lang.sh
#missing charset
chmod +x $CHROOTDIR/etc/profile.d/lang.sh

rm -f $TREE/rootfs.img
dd if=/dev/zero of=$TREE/rootfs.img bs=1M count=1024
mkfs.ext4 -F $TREE/rootfs.img
loop=$(mktemp -d)
mount -o loop $TREE/rootfs.img $loop
cp -a $CHROOTDIR/* $loop
df -h $loop
umount $loop
rmdir $loop

# TODO see later if this reduces size
#e2fsck -f rootfs.img
#resize2fs rootfs.img -M

mkdir -p $TREE/squashfs-root/LiveOS
mv $TREE/rootfs.img $TREE/squashfs-root/LiveOS
# TODO can be xz
rm -f $TREE/squashfs.img
mksquashfs $TREE/squashfs-root $TREE/squashfs.img -comp gzip
