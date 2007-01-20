#!/bin/bash

checkpkg()
{
	pacman -Q $1 -r $root &>/dev/null
	return $?
}

if [ "$UID" != 0 ] ; then
	echo "you are not root. bye"
	exit 1
fi

if [ -z "$1" -o -z "$2" ] ; then
	echo "usage: $0 out.mo pkg1 [ pkg2 [ ... ] ]"
	exit 1
fi

source /usr/lib/liblinuxlive

root="root"

output="$1"
shift

mkdir -p $root/{tmp,var/cache/pacman/pkg}
mount -o bind /var/cache/pacman $root/var/cache/pacman
pacman -Sy $* -r $root --noconfirm
umount $root/var/cache/pacman/
pacman -Rdn $(pacman -Q -r $root|sed 's/ .*//'|egrep -v "$(echo "$*" |sed 's/ /|/g')") -r $root --noconfirm

# clean up the junk
find $root -name '*.pacsave' |sudo xargs rm -f
for i in `ls $root/var/lib/pacman`
do
	[ "$i" != "local" ] && rm -rf $root/var/lib/pacman/$i
done
checkpkg shadow || rm -rf $root/{etc/group-,etc/passwd-,etc/.pwd.lock,etc/shadow-}
checkpkg gtk+2 || rm -rf $root/etc/gtk-2.0
checkpkg pango || rm -rf $root/etc/pango/pango.modules
checkpkg fontconfig || rm -rf $root/{var/cache/fontconfig,fonts.scale}
checkpkg texinfo || rm -rf $root/usr/info/dir
checkpkg expat || rm -rf $root/usr/lib/libexpat.so.0
checkpkg termcap || rm -rf $root/usr/lib/libtermcap.so.2
checkpkg glibc || rm -rf $root/etc/ld.so.cache
checkpkg hald || rm -rf $root/{etc/rc.d/rc?.d/???rc.hald,var/spool/mail/hald}
checkpkg dbus || rm -rf $root/{etc/rc.d/rc?.d/???rc.dbus,var/spool/mail/messagebus}
checkpkg e2fsprogs || rm -rf $root/etc/rc.d/rc?.d/???rc.{fsck,random}
checkpkg avahi || rm -rf $root/var/spool/mail/avahi

create_module $root $output
rm -rf $root
