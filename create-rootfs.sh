#!/bin/bash -xe

. /etc/makepkg.conf
. $PWD/config 

if [ "`id -u`" != 0 ]; then
	echo "Building the chroot as an unprivileged user is not possible."
	exit 1
fi

# Mount loop
mkdir -p $CHROOTDIR
rm -f $TREE/rootfs.img
dd if=/dev/zero of=$TREE/rootfs.img bs=1M count=1024
mkfs.ext4 -F $TREE/rootfs.img
mount -o loop $TREE/rootfs.img $CHROOTDIR
mkdir -p $CHROOTDIR/{etc,proc,sys,var/cache/pacman-g2,var/tmp/fst,tmp,var/log}

# Mount chroot
echo "Attempting to mount chroot directories..."
mount -t proc none $CHROOTDIR/proc >/dev/null
mount -t sysfs none $CHROOTDIR/sys >/dev/null
mount -o bind /var/cache/pacman-g2 $CHROOTDIR/var/cache/pacman-g2 >/dev/null
echo "Successfully mounted chroot directories."

# Pre-install tweaks
mkdir -p $CHROOTDIR/etc/{profile.d,sysconfig}
## file /etc/profile.d/lang.sh
echo "export LANG=$FWLIVELANG" >$CHROOTDIR/etc/profile.d/lang.sh
echo "export LC_ALL=\$LANG" >> $CHROOTDIR/etc/profile.d/lang.sh
if [ "`echo $FWLIVELANG|sed 's/.*\.\(.*\).*/\1/'`" == utf8 ]; then
	echo "export CHARSET=utf-8" >> $CHROOTDIR/etc/profile.d/lang.sh
else
	case $FWLIVELANG in
		en_US)
			echo "export CHARSET=iso-8859-1" >> $CHROOTDIR/etc/profile.d/lang.sh ;;
		fr_FR)
			echo "export CHARSET=iso-8859-15" >> $CHROOTDIR/etc/profile.d/lang.sh;;
		*)	
			echo "export CHARSET=iso-8859-15" >> $CHROOTDIR/etc/profile.d/lang.sh;;
		esac
fi
chmod +x $CHROOTDIR/etc/profile.d/lang.sh
## file /etc/sysconfig/keymap
## TODO:To improve the function ( ex : for french keymap=fr-latin1 )
case $FWLIVELANG in
	en_*)
		keymap=us ;;
	*)
		keymap=`echo $FWLIVELANG |sed 's/_.*//'` ;;
esac
echo "keymap=$keymap" > $CHROOTDIR/etc/sysconfig/keymap
# file /etc/fstab - just to make systemd-remount-api-vfs.service happy
cat >$CHROOTDIR/etc/fstab <<EOF
none             /proc            proc        defaults         0   0
none             /sys             sysfs       defaults         0   0
devpts           /dev/pts         devpts      gid=5,mode=620   0   0
usbfs            /proc/bus/usb    usbfs       devgid=23,devmode=664 0   0
tmpfs            /dev/shm         tmpfs       defaults         0   0
EOF

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

# Post-install tweaks
chroot $CHROOTDIR sh -c 'echo "root:fwlive" | chpasswd'

# Umount chroot
echo "Attempting to umount chroot directories..."
umount $CHROOTDIR/proc >/dev/null
umount $CHROOTDIR/sys >/dev/null
umount $CHROOTDIR/var/cache/pacman-g2 >/dev/null
echo "Successfully umounted chroot directories."

# Umount loop
df -h $CHROOTDIR
umount $CHROOTDIR
rmdir $CHROOTDIR
# TODO see later if this reduces size
#e2fsck -f rootfs.img
#resize2fs rootfs.img -M