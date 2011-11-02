qemu-system-x86_64 -enable-kvm -m 512 -kernel rootfs/boot/vmlinuz -initrd rootfs/boot/initrd.img.xz \
	-append "root=live:CDLABEL=fwlive rd.driver.pre=loop rd.plymouth=0" -cdrom fwlive.iso
