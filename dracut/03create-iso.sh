#!/bin/bash -xe

rm -rf iso
#Create Iso with grub
#TODO: add frugalware gfx
mkdir -p iso/boot/grub
cp -v rootfs/boot/vmlinuz iso/boot/
cp -v rootfs/boot/initrd.img.xz iso/boot/
cp -v rootfs/usr/lib/grub/i386-frugalware/stage2_eltorito iso/boot/grub/
cat >iso/boot/grub/menu.lst <<EOF
default=0
timeout=5

title FwLive (Fermus) - 3.1-fw1
	kernel /boot/vmlinuz root=live:CDLABEL=fwlive rd.driver.pre=loop rd.plymouth=0
	initrd /boot/initrd.img.xz
EOF
mkdir -p iso/LiveOS
cp -v squashfs.img iso/LiveOS
mkisofs -R -J -V fwlive -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -o fwlive.iso iso
