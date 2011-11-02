#!/bin/bash

. /etc/makepkg.conf
. $PWD/config 

chroot_umount() {
	echo "Attempting to umount chroot directories..."
	umount $CHROOTDIR/proc >/dev/null
	umount $CHROOTDIR/sys >/dev/null
	umount $CHROOTDIR/var/cache/pacman-g2 >/dev/null
	if [ "$?" != "0" ]; then
		echo "An error occurred while attempting to umount chroot directories."
		exit 1
	fi
	echo "Successfully umounted chroot directories."
}

chroot_mount() {
	echo "Attempting to mount chroot directories..."
	mount -t proc none $CHROOTDIR/proc >/dev/null
	mount -t sysfs none $CHROOTDIR/sys >/dev/null
	mount -o bind /var/cache/pacman-g2 $CHROOTDIR/var/cache/pacman-g2 >/dev/null
	if [ "$?" != "0" ]; then
		echo "An error occurred while attempting to mount chroot directories."
		exit 1
	fi
	echo "Successfully mounted chroot directories."
}

# Create the chroot environment.
if [ "`id -u`" != 0 ]; then
	echo "Building the chroot as an unprivileged user is not possible."
	exit 1
fi

rm -rf $CHROOTDIR
mkdir -p $CHROOTDIR/{etc,proc,sys,var/cache/pacman-g2,var/tmp/fst,tmp,var/log}

chroot_mount

echo "Building chroot environment"

[ -e pacman-g2.conf ] && rm -f pacman-g2.conf;
[ $TREE == "current" ] && echo "[frugalware-current]" > pacman-g2.conf
[ $TREE == "stable" ] && echo "[frugalware]" > pacman-g2.conf
echo "Server = http://ftp.frugalware.org/pub/frugalware/frugalware-$TREE/frugalware-$ARCH" >> pacman-g2.conf

pacman -Sy base -r "$CHROOTDIR" --noconfirm --config pacman-g2.conf

if [ "$?" != "0" ]; then
	echo "Failed to build chroot environment."
	chroot_umount
	exit 1
fi
chroot_umount
