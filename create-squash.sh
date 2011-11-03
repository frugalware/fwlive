#!/bin/bash -xe

. $PWD/config 

if [ "`id -u`" != 0 ]; then
	echo "Not root"
	exit 1
fi

mkdir -p $TREE/squashfs-root/LiveOS
mv $TREE/rootfs.img $TREE/squashfs-root/LiveOS
# TODO can be xz
rm -f $TREE/squashfs.img
mksquashfs $TREE/squashfs-root $TREE/squashfs.img -comp gzip
