#!/bin/bash -xe

. /etc/makepkg.conf
. $PWD/config 

if [ "`id -u`" != 0 ]; then
	echo "Building the chroot as an unprivileged user is not possible."
	exit 1
fi

# Create empty dir
rm -rf $CHROOTDIR
mkdir -p $CHROOTDIR/{etc,proc,sys,var/cache/pacman-g2,var/tmp/fst,tmp,var/log}

# Mount chroot
echo "Attempting to mount chroot directories..."
mount -t proc none $CHROOTDIR/proc >/dev/null
mount -t sysfs none $CHROOTDIR/sys >/dev/null
mount -o bind /var/cache/pacman-g2 $CHROOTDIR/var/cache/pacman-g2 >/dev/null
echo "Successfully mounted chroot directories."

# Build it
echo "Building chroot environment"
if [ -e pacman-g2.conf ]; then
	rm -f pacman-g2.conf
fi
if [ $TREE == "current" ]; then
	echo "[frugalware-current]" > pacman-g2.conf
fi
if [ $TREE == "stable" ]; then
	echo "[frugalware]" > pacman-g2.conf
fi
echo "Server = http://ftp.frugalware.org/pub/frugalware/frugalware-$TREE/frugalware-$ARCH" >> pacman-g2.conf
pacman -Sy base -r "$CHROOTDIR" --noconfirm --config pacman-g2.conf

# Umount
echo "Attempting to umount chroot directories..."
umount $CHROOTDIR/proc >/dev/null
umount $CHROOTDIR/sys >/dev/null
umount $CHROOTDIR/var/cache/pacman-g2 >/dev/null
echo "Successfully umounted chroot directories."
