# Makefile for livecd creation
#
# The only tested entry points/targets are:
# really-clean - should clean the chroot & co.
# all - should do everything in one BIG	step (now it only installs pkgs to chroot)
#
# Preferably you want to run sudo make really-clean before sudo make all ;)
#
# temporary chroot where livecd's fs will be built
#
-include configs
CHROOTDIR = $(shell source /etc/makepkg.conf; echo $$CHROOTDIR)/fwlive
$(shell touch /tmp/tmp.fwlivetmp)
PACCONF = /tmp/tmp.fwlivetmp
KERNVER = pacman -r ${CHROOTDIR}/${TREE} -Q kernel-fwlive|cut -d ' ' -f2|sed 's/-/-fwlive-fw/'
# needed files (files that we can't live without)
NEED_FILES = sysctl-added_cdrom_locking.diff fstab-update xstart \
	crypt.c	rc.fwlive rc.config configsave issue fileswap reboot.diff services.diff udev.diff \
	rc.parse_cmdline parse_cmdline.en parse_cmdline.hu parse_cmdline mount_fsck.diff 
INST_FILES_755 = /etc/rc.d/rc.fwlive /etc/rc.d/rc.config /usr/local/bin/configsave \
	/usr/local/bin/fileswap /usr/local/bin/fstab-update /usr/local/bin/xstart \
	/usr/local/bin/parse_cmdline /etc/rc.d/rc.parse_cmdline /tmp/live-base/tools/fpm2lzm
INST_FILES_644 = /etc/issue /etc/rc.d/rc.messages/parse_cmdline.hu /etc/rc.d/rc.messages/parse_cmdline.en 
PWD = $(shell pwd)
PATCH_FILES = sysctl-added_cdrom_locking.diff reboot.diff services.diff udev.diff mount_fsck.diff
REMOVE_FILES = /etc/rc.d/rcS.d/S{19rc.bootclean,07rc.frugalware} \
	   /etc/rc.d/rc{3.d,4.d}/S{21rc.firewall,26rc.lmsensors,32rc.sshd,78rc.mysqld,80rc.postfix,81rc.courier-authlib,82rc.imapd,82rc.pop3d,85rc.httpd,95rc.crond,99rc.cups,99rc.mono,99cups,12rc.syslog,13rc.portmap,19rc.rmount,50rc.atd} \
	   /etc/rc.d/rc0.d/K{00cups,01rc.cups,05rc.crond,60rc.atd,87rc.portmap,88rc.syslog,90rc.rmount,96rc.swap,98rc.interfaces,56rc.sshd,30rc.postfix} \
	   /etc/rc.d/rc6.d/K{01rc.cups,05rc.crond,60rc.atd,87rc.portmap,88rc.syslog,90rc.rmount,96rc.swap,98rc.interfaces,56rc.sshd,30rc.postfix} \
	   /etc/frugalware-release
CC = cc

all: checkroot check-tree checkfiles chroot-mkdirs create-pkgdb cache-mount install-base install-apps install-kernel cache-umount install-files patch-files remove-files kill-packages create-symlinks create-files fix-files create-users live-base create
	@echo "Finally, we do nothing more by now."
	@echo "Now burn your iso and have fun!"

check-tree:
	if grep -q ^Include.*current$$ /etc/pacman.conf; then \
		if [ "${TREE}" = "current" ]; then \
			cat /etc/pacman.conf > ${PACCONF}; \
		else \
			cat /etc/pacman.conf |sed 's|^\(Include = /etc/pacman.d/frugalware-current$$\)|#\1| ; \
				s|^#\(Include = /etc/pacman.d/frugalware$$\)|\1|'> ${PACCONF}; \
		fi \
	else \
		if [ "${TREE}" = "current" ]; then \
			cat /etc/pacman.conf |sed 's|^#\(Include = /etc/pacman.d/frugalware-current$$\)|\1| ; \
				s|^\(Include = /etc/pacman.d/frugalware$$\)|#\1|' > ${PACCONF}; \
		else \
			cat /etc/pacman.conf > ${PACCONF} ; \
		fi \
	fi 

checkfiles:
	for i in ${NEED_FILES}; do \
		if [ ! -f $$i ] ; then \
			echo "Missing file: $$i"; \
			exit 2; \
		fi; \
	done

checkroot:
	if (( $$(id -u) > 0 )) ; then \
		echo "Only root can execute this script! (Or at least with this target...)"; \
		exit 3; \
	fi

chroot-mkdirs: checkroot
	mkdir -p ${CHROOTDIR}/${TREE}/{dev,etc,proc,sys,var/cache/pacman,var/log}
	
create-pkgdb: checkroot
	pacman -r ${CHROOTDIR}/${TREE} -Syuf --noconfirm --config ${PACCONF}

# pacman should really have a --dont-reinstall switch
install-base: checkroot
	if [ ! -d "${CHROOTDIR}/${TREE}/usr" ] ; then \
		pacman -r ${CHROOTDIR}/${TREE} -Sf base --noconfirm --config ${PACCONF} ; \
	fi

install-apps: checkroot
	if [ "${INST_${APPSGROUP}_APPS}" ] ; then \
		if (( $(shell pacman -r ${CHROOTDIR}/${TREE} -Q kernel-fwlive &>/dev/null; echo $$?) > 0 )) ; then \
			pacman -r ${CHROOTDIR}/${TREE} -Sf ${INST_${APPSGROUP}_APPS} --noconfirm --config ${PACCONF} ; \
		fi ; \
	fi

install-kernel: checkroot
	if (( $(shell pacman -r ${CHROOTDIR}/${TREE} -Q kernel-fwlive &>/dev/null; echo $$?) > 0 )) ; then \
		pacman -r ${CHROOTDIR}/${TREE} -Sf kernel-fwlive --noconfirm --config ${PACCONF} ; \
	fi

install-files: checkroot
	for i in ${INST_FILES_755}; do \
		install -m 755 -g root -o root -D $$(basename $$i) ${CHROOTDIR}/${TREE}/$$i; \
	done
	for i in ${INST_FILES_644}; do \
		install -m 644 -g root -o root -D $$(basename $$i) ${CHROOTDIR}/${TREE}/$$i; \
	done

#patch -p0 -R --dry-run -N -i -b ${PWD}/$$i
patch-files: checkroot
	cd ${CHROOTDIR}/${TREE}; \
	for i in ${PATCH_FILES}; do \
		patch -p0 -i ${PWD}/$$i; \
	done; \
	cd ${PWD}

create-symlinks: checkroot
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S35rc.parse_cmdline ] ; then \
		ln -s ../rc.parse_cmdline ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S35rc.parse_cmdline ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S07rc.fwlive ] ; then \
		ln -s ../rc.fwlive ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S07rc.fwlive ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S17rc.config ] ; then \
		ln -s ../rc.config ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S17rc.config ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rc6.d/K94rc.config ] ; then \
		ln -s ../rc.config ${CHROOTDIR}/${TREE}/etc/rc.d/rc6.d/K94rc.config ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rc0.d/K94rc.config ] ; then \
		ln -s ../rc.config ${CHROOTDIR}/${TREE}/etc/rc.d/rc0.d/K94rc.config ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/frugalware-release ] ; then \
		ln -s fwlive-release ${CHROOTDIR}/${TREE}/etc/frugalware-release ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/var/tmp ] ; then \
		ln -s /tmp ${CHROOTDIR}/${TREE}/var/tmp ; \
	fi

remove-files: checkroot
	for i in ${REMOVE_FILES}; do \
		rm -f ${CHROOTDIR}/${TREE}/$$i; \
	done

kill-packages:
	if [ $(shell pacman -r ${CHROOTDIR}/${TREE} -Q splashy &>/dev/null; echo $$?) = 0 ] ; then \
		pacman -r ${CHROOTDIR}/${TREE} -Rf splashy --noconfirm --config ${PACCONF} ; \
	fi

create-files: checkroot
	echo "UTC" >${CHROOTDIR}/${TREE}/etc/hardwareclock
	echo "${FWLHOST}" >${CHROOTDIR}/${TREE}/etc/HOSTNAME
	echo "${BIGN} ${FWLREL}, based on Frugalware Linux ${FWREL}" >${CHROOTDIR}/${TREE}/etc/fwlive-release
	echo "export LANG=${FWLLLANG}" >${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	echo "export LC_ALL=$$LANG" >>${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	echo "export CHARSET=${FWLCP}" >>${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	chmod +x ${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	echo 'desktop=""' >${CHROOTDIR}/${TREE}/etc/sysconfig/desktop
	echo "font=${FWLFONT}" >${CHROOTDIR}/${TREE}/etc/sysconfig/font
	echo "[eth0]" >${CHROOTDIR}/${TREE}/etc/sysconfig/network/default
	echo "options = dhcp" >>${CHROOTDIR}/${TREE}/etc/sysconfig/network/default
	echo "127.0.0.1       localhost" >${CHROOTDIR}/${TREE}/etc/hosts
	sed "s|id:4:initdefault:|id:3:initdefault:|" ${CHROOTDIR}/${TREE}/etc/inittab

# FIXME: do we need this esd check at all?
fix-files: checkroot
	if [ -f ${CHROOTDIR}/${TREE}/etc/esd.conf ]; then \
		sed -i 's|terminate|no&|' ${CHROOTDIR}/${TREE}/etc/esd.conf; \
	fi

create-users: checkroot
	if (( $(shell grep ${FWLUSER} ${CHROOTDIR}/${TREE}/etc/shadow &>/dev/null; echo $$?) > 0 )); then \
		chroot ${CHROOTDIR}/${TREE} /usr/sbin/useradd -g users -G floppy,cdrom,scanner,audio,camera,video -m -u 1000 ${FWLUSER}; \
		chroot ${CHROOTDIR}/${TREE} /bin/chown -R ${FWLUSER}:users /home/${FWLUSER}; \
		${CC} -lcrypt crypt.c -o crypt_fwlive; \
		fwpass=$$(./crypt_fwlive ${FWUSERPASS}); \
		rootpass=$$(./crypt_fwlive ${FWROOTPASS}); \
		rof=$$(cat ${CHROOTDIR}/${TREE}/etc/shadow|grep ^root|awk -F ':' '{print $$3}'); \
		fwf=$$(cat ${CHROOTDIR}/${TREE}/etc/shadow|grep ^${FWLUSER}|awk -F ':' '{print $$3}'); \
		sed "s|${FWLUSER}:\!:$$fwf|${FWLUSER}:$$fwpass:$$fwf|" -i ${CHROOTDIR}/${TREE}/etc/shadow; \
		sed "s|root::$$rof|root:$$rootpass:$$rof|" -i ${CHROOTDIR}/${TREE}/etc/shadow; \
		echo "${FWLUSER}    ALL=(ALL) NOPASSWD:ALL" >${CHROOTDIR}/${TREE}/etc/sudoers; \
		sed "s|bigname|${BIGN}|" -i ${CHROOTDIR}/${TREE}/etc/issue; \
		sed "s|v0.0|${FWLSREL}|" -i ${CHROOTDIR}/${TREE}/etc/issue; \
		sed "s|username|${FWLUSER}|" -i ${CHROOTDIR}/${TREE}/etc/issue; \
		sed "s|userpass|${FWUSERPASS}|" -i ${CHROOTDIR}/${TREE}/etc/issue; \
		sed "s|rootpass|${FWROOTPASS}|" -i ${CHROOTDIR}/${TREE}/etc/issue; \
		sed "s|SAVE_DIRS|${SAVEDIRS}|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/configsave; \
	fi

live-base: checkroot
	cp -a live-base ${CHROOTDIR}/${TREE}/tmp/
	ln -sf configsave ${CHROOTDIR}/${TREE}/usr/local/bin/configrestore
	cp ${CHROOTDIR}/${TREE}/tmp/live-base/tools/* ${CHROOTDIR}/${TREE}/usr/local/bin/
	cp ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/linux/make_iso.sh ${CHROOTDIR}/${TREE}/usr/local/bin/
	ln -sf make_iso.sh ${CHROOTDIR}/${TREE}/usr/local/bin/make_iso
	ln -sf install ${CHROOTDIR}/${TREE}/tmp/live-base/uninstall
	ln -sf ../tools/liblinuxlive ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/liblinuxlive

live-base-to: live-base
	sed -i 's/`uname -r`/$(shell ${KERNVER})/' ${CHROOTDIR}/${TREE}/tmp/live-base/.config
	sed -i  "s|linuxcd|${FWLSREL}|" ${CHROOTDIR}/${TREE}/tmp/live-base/.config
	sed -i "s|Live|${FWLREL}|" ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/linux/make_iso.sh
	sed -i "s|KERNEL=.*|KERNEL=\"$(shell ${KERNVER})\"|" ${CHROOTDIR}/${TREE}/tmp/live-base/.config

live-bin: checkroot
	pacman -r ${CHROOTDIR}/${TREE} -Sf ${INST_BIN_APPS} --noconfirm --config ${PACCONF}
	cp ${CHROOTDIR}/${TREE}/sbin/blkid ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/sbin/blockdev ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/usr/share/busybox/bin/busybox ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/usr/bin/eject ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/usr/sbin/lspci ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/lib/ld-2.5.so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s ld-2.5.so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/ld-linux.so.2
	cp ${CHROOTDIR}/${TREE}/lib/libblkid.so.1.0 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libblkid.so.1.0 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libblkid.so.1
	cp ${CHROOTDIR}/${TREE}/lib/libc-2.5.so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libc-2.5.so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libc.so.6
	cp ${CHROOTDIR}/${TREE}/lib/libuuid.so.1.2 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libuuid.so.1.2 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libuuid.so.1
	cp ${CHROOTDIR}/${TREE}/usr/lib/libz.so.1.2.3 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libz.so.1.2.3 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libz.so
	ln -s libz.so.1.2.3 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libz.so.1
	cp ${CHROOTDIR}/${TREE}/usr/bin/mksquashfs ${CHROOTDIR}/${TREE}/tmp/live-base/tools/
	cp ${CHROOTDIR}/${TREE}/usr/bin/unsquashfs ${CHROOTDIR}/${TREE}/tmp/live-base/tools/
	cp ${CHROOTDIR}/${TREE}/boot/memtest.bin ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/
	cp ${CHROOTDIR}/${TREE}/usr/lib/grub/i386-pc/stage2_eltorito ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/
	cp ${CHROOTDIR}/${TREE}/boot/grub/message-frugalware ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/
	ln -s message ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/message-frugalware
	cp menu.lst ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/
	sed "s|NAME|${FWLREL}|" ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/menu.lst
	pacman -r ${CHROOTDIR}/${TREE} -Rd ${INST_BIN_APPS} --noconfirm --config ${PACCONF}

create: chroot-mount create-iso chroot-umount
	echo "./${ISONAME}-${FWLSREL}.iso created."

create-iso: checkroot
	chroot ${CHROOTDIR}/${TREE} /sbin/depmod -ae -v $(shell ${KERNVER})
	chroot ${CHROOTDIR}/${TREE} /tmp/live-base/build
	mv ${CHROOTDIR}/${TREE}/tmp/livecd.iso ./${ISONAME}-${FWLSREL}.iso
	cp ${ISONAME}-${FWLSREL}.iso /var/cache/pacman/
	echo "Won't calculate any sums. Period."

chroot-mount: checkroot
	if [ ! $(shell mount|grep -o ${CHROOTDIR}/${TREE}/proc) ] ; then \
		mount -t proc none ${CHROOTDIR}/${TREE}/proc ; \
	fi
	if [ ! $(shell mount|grep -o ${CHROOTDIR}/${TREE}/sys) ] ; then \
		mount -t sysfs none ${CHROOTDIR}/${TREE}/sys ; \
	fi
	if [ ! $(shell mount|grep -o ${CHROOTDIR}/${TREE}/dev) ] ; then \
		mount -o bind /dev ${CHROOTDIR}/${TREE}/dev ; \
	fi

cache-mount: checkroot
	if [ ! $(shell mount|grep -o ${CHROOTDIR}/${TREE}/var/cache/pacman) ] ; then \
		mount -o bind /var/cache/pacman ${CHROOTDIR}/${TREE}/var/cache/pacman ; \
	fi

chroot-umount: checkroot
	umount ${CHROOTDIR}/${TREE}/{proc,sys,dev} &>/dev/null

cache-umount: checkroot
	if [ $(shell mount|grep -o ${CHROOTDIR}/${TREE}/var/cache/pacman) ] ; then \
		umount ${CHROOTDIR}/${TREE}/var/cache/pacman; \
	fi

clean:
	rm -f ${ISONAME}-${FWLSREL}.iso crypt_fwlive

really-clean: checkroot
	rm -rf ${CHROOTDIR}/${TREE}
