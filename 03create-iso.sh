#!/bin/bash -xe

. $PWD/config

rm -rf $TREE/iso
#Create Iso with grub
#TODO: add fwlive gfx
mkdir -p $TREE/iso/boot/grub
cp -v $TREE/rootfs/boot/grub/message $TREE/iso/boot/grub/
cp -v $TREE/rootfs/boot/vmlinuz $TREE/iso/boot/
cp -v $TREE/rootfs/boot/initrd.img.xz $TREE/iso/boot/
cp -v $TREE/rootfs/usr/lib/grub/i386-frugalware/stage2_eltorito $TREE/iso/boot/grub/
cat >$TREE/iso/boot/grub/menu.lst <<EOF
default=0
timeout=5
gfxmenu /boot/grub/message

title FwLive-$TREE (Dalek)
	kernel /boot/vmlinuz root=live:CDLABEL=fwlive rd.driver.pre=loop rd.plymouth=0
	initrd /boot/initrd.img.xz
EOF
mkdir -p $TREE/iso/LiveOS
cp -v $TREE/squashfs.img $TREE/iso/LiveOS/squashfs.img
mkisofs -R -J -V fwlive -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -o fwlive-$TREE.iso $TREE/iso
