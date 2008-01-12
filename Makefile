#
# Makefile for livecd creation
#

ARCH = $(shell uname -m)
-include config
CHROOTDIR = $(shell source /etc/makepkg.conf; echo $$CHROOTDIR)/fwlive
PACCONF := $(shell mktemp)
FWLSLANG = $(shell echo $(FWLLLANG)|sed 's/_.*//')
KERNVER = pacman-g2 -r ${CHROOTDIR}/${TREE} -Q kernel-fwlive|cut -d ' ' -f2|sed 's/-/-fw/'
GLIBCVER = pacman-g2 -r ${CHROOTDIR}/${TREE} -Q glibc|sed 's/.* \(.*\)-.*/\1/'
FWLREL = pacman-g2 -r ${CHROOTDIR}/${TREE} -Q frugalware |sed 's/.* \(.*\)-.*/\1/'
ifeq ($(CONFIG_SETUP),y)
SETUPDIR = ${CHROOTDIR}/${TREE}/usr/share/setup
SETUPKERNELVER = cd $(SETUPDIR); ls vmlinuz*|sed 's/vmlinuz-//'
SETUPKERNEL = $(SETUPDIR)/vmlinuz-$(shell ${SETUPKERNELVER})
SETUPINITRD = $(SETUPDIR)/initrd-$(ARCH).img.gz
SETUPINITRDSIZE = echo "$$(($$(gzip --list $(SETUPINITRD) |grep initrd-$(ARCH).img|sed 's/.*[0-9]\+ \+\([0-9]\+\) .*/\1/')/1024))"
endif
# needed files (files that we can't live without)
NEED_FILES = fstab-update parse_cmdline.in xorg.conf.in rc.fsupd \
	crypt.c	rc.fwlive rc.config configsave fileswap reboot.diff services.diff udev.diff rc.S.diff \
	rc.parse_cmdline parse_cmdline xstart xorg.conf menu.lst 
INST_FILES_755 = /etc/rc.d/rc.fwlive /etc/rc.d/rc.config /etc/rc.d/rc.fsupd /usr/local/bin/configsave \
	/usr/local/bin/fileswap /usr/local/bin/fstab-update /usr/local/bin/xstart \
	/usr/local/bin/parse_cmdline /etc/rc.d/rc.parse_cmdline /tmp/live-base/tools/fpm2lzm
INST_FILES_644 = /etc/X11/xorg.conf /boot/grub/menu.lst
PWD = $(shell pwd)
PATCH_FILES = reboot.diff services.diff udev.diff rc.S.diff
REMOVE_FILES = /etc/rc.d/rcS.d/S{19rc.bootclean,07rc.frugalware} \
	   /etc/rc.d/rc{3.d,4.d}/S{21rc.firewall,26rc.lmsensors,32rc.sshd,78rc.mysqld,80rc.postfix,81rc.courier-authlib,82rc.imapd,82rc.pop3d,85rc.httpd,95rc.crond,99rc.cups,99rc.mono,99cups,12rc.syslog,13rc.portmap,19rc.rmount,50rc.atd} \
	   /etc/rc.d/rc0.d/K{00cups,01rc.cups,05rc.crond,60rc.atd,87rc.portmap,88rc.syslog,90rc.rmount,96rc.swap,98rc.interfaces,56rc.sshd,30rc.postfix} \
	   /etc/rc.d/rc6.d/K{01rc.cups,05rc.crond,60rc.atd,87rc.portmap,88rc.syslog,90rc.rmount,96rc.swap,98rc.interfaces,56rc.sshd,30rc.postfix} \
	   /etc/frugalware-release
CC = cc

all: checkroot check-tree checkfiles chroot-mkdirs create-pkgdb cache-mount install-base install-apps install-kernel cache-umount install-files patch-files remove-files create-symlinks create-files fix-files create-users live-base hacking-kdmrc kill-packages create
	@echo "Finally, we do nothing more by now."
	@echo "Now burn your iso and have fun!"

check-tree:
	source /etc/repoman.conf; \
	grep -v Include /etc/pacman-g2.conf >${PACCONF}; \
        echo "[janny]" >> ${PACCONF}; \
        echo "Server = http://ftp.frugalware.org/pub/other/people/janny/fwlive/frugalware-i686/" >> ${PACCONF}; \
	if [ ${APPSGROUP} == "KDE4" ] ; then \
	        echo "[playground]" >> ${PACCONF}; \
	        echo "Server = http://ftp.frugalware.org/pub/other/people/crazy/playground/frugalware-i686" >> ${PACCONF}; \
	fi
	for i in `echo ${TREE}|sed 's/,/ /g'`; do \
		repo=$$(eval "echo \$${$${i}_fdb/.fdb}"); \
		[ -z "$$repo" ] && repo="$$i"; \
		echo "[frugalware-$$repo]" >> ${PACCONF}; \
		echo "Server = http://ftp.frugalware.org/pub/frugalware/frugalware-$$repo/frugalware-i686" >> ${PACCONF}; \
	done

parse_cmdline: parse_cmdline.in
	sed 's/FWLLLANG/$(FWLLLANG)/' $@.in > $@

xorg.conf: xorg.conf.in
	sed 's/@FWLSLANG@/$(FWLSLANG)/' $@.in > $@
	sed -i 's/"en"/"us"/' $@

checkfiles: parse_cmdline xorg.conf
	${MAKE} -C po pos
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
	mkdir -p ${CHROOTDIR}/${TREE}/{dev,etc,proc,sys,var/cache/pacman-g2,var/log}
	
create-pkgdb: checkroot
	pacman-g2 -r ${CHROOTDIR}/${TREE} -Syuf --noconfirm --config ${PACCONF}

# pacman should really have a --dont-reinstall switch
install-base: checkroot
	if [ ! -d "${CHROOTDIR}/${TREE}/usr" ] ; then \
		pacman-g2 -r ${CHROOTDIR}/${TREE} -Sf base --noconfirm --config ${PACCONF} ; \
	fi

install-apps: checkroot
	if [ "${INST_${APPSGROUP}_APPS}" ] ; then \
		if (( $(shell pacman-g2 -r ${CHROOTDIR}/${TREE} -Q kernel-fwlive &>/dev/null; echo $$?) > 0 )) ; then \
			pacman-g2 -r ${CHROOTDIR}/${TREE} -Sf ${INST_${APPSGROUP}_APPS} --noconfirm --config ${PACCONF} ; \
		fi ; \
	fi

install-kernel: checkroot
	if (( $(shell pacman-g2 -r ${CHROOTDIR}/${TREE} -Q kernel-fwlive &>/dev/null; echo $$?) > 0 )) ; then \
		pacman-g2 -r ${CHROOTDIR}/${TREE} -Sf kernel-fwlive --noconfirm --config ${PACCONF} ; \
	fi

install-files: checkroot
	for i in ${INST_FILES_755}; do \
		install -m 755 -g root -o root -D $$(basename $$i) ${CHROOTDIR}/${TREE}/$$i; \
	done
	for i in ${INST_FILES_644}; do \
		install -m 644 -g root -o root -D $$(basename $$i) ${CHROOTDIR}/${TREE}/$$i; \
	done
	${MAKE} -C po CHROOTDIR=${CHROOTDIR} TREE=${TREE} mos

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
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S16rc.fsupd ] ; then \
	    ln -s ../rc.fsupd ${CHROOTDIR}/${TREE}/etc/rc.d/rcS.d/S16rc.fsupd ; \
	fi
	if [ ! -e ${CHROOTDIR}/${TREE}/etc/rc.d/rc6.d/K95rc.fsupd ] ; then \
		ln -s ../rc.fsupd ${CHROOTDIR}/${TREE}/etc/rc.d/rc6.d/K95rc.fsupd ; \
	fi

remove-files: checkroot
	for i in ${REMOVE_FILES}; do \
		rm -f ${CHROOTDIR}/${TREE}/$$i; \
	done

kill-packages:
	if [ $(shell pacman-g2 -r ${CHROOTDIR}/${TREE} -Q splashy &>/dev/null; echo $$?) = 0 ] ; then \
		pacman-g2 -r ${CHROOTDIR}/${TREE} -Rf splashy --noconfirm --config ${PACCONF} ; \
	fi
	if [ $(shell pacman-g2 -r ${CHROOTDIR}/${TREE} -Q fwsetup &>/dev/null; echo $$?) = 0 ] ; then \
		pacman-g2 -r ${CHROOTDIR}/${TREE} -Rf fwsetup --noconfirm --config ${PACCONF} ; \
	fi

create-files: checkroot
	cp -f ${PACCONF} ${CHROOTDIR}/${TREE}/etc/pacman-g2.conf
	echo "UTC" >${CHROOTDIR}/${TREE}/etc/hardwareclock
	echo "${FWLHOST}" >${CHROOTDIR}/${TREE}/etc/HOSTNAME
	echo "FWLive $(shell ${FWLREL}) (${FWLCODENAME}), based on Frugalware Linux ${FWREL}" >${CHROOTDIR}/${TREE}/etc/fwlive-release
	echo 'desktop=""' >${CHROOTDIR}/${TREE}/etc/sysconfig/desktop
	echo "font=${FWLFONT}" >${CHROOTDIR}/${TREE}/etc/sysconfig/font
	echo "export LANG=${FWLLLANG}" >${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	echo 'export LC_ALL=$$LANG' >>${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	chmod +x ${CHROOTDIR}/${TREE}/etc/profile.d/lang.sh
	echo "[eth0]" >${CHROOTDIR}/${TREE}/etc/sysconfig/network/default
	echo "options = dhcp" >>${CHROOTDIR}/${TREE}/etc/sysconfig/network/default
	echo "127.0.0.1		localhost	${FWLHOST}" >${CHROOTDIR}/${TREE}/etc/hosts
	sed -i "s|id:4:initdefault:|id:3:initdefault:|" ${CHROOTDIR}/${TREE}/etc/inittab
	sed -i "s|NUMLOCK_ON=1|NUMLOCK_ON=0|" ${CHROOTDIR}/${TREE}/etc/sysconfig/numlock
	sed -i "s|dev.cdrom.lock=0|dev.cdrom.lock=1|" ${CHROOTDIR}/${TREE}/etc/sysctl.conf
	sed -i "s|/sbin/fsck|true|" ${CHROOTDIR}/${TREE}/etc/rc.d/rc.fsck

# FIXME: do we need this esd check at all?
fix-files: checkroot
	if [ -f ${CHROOTDIR}/${TREE}/etc/esd.conf ]; then \
		sed -i 's|terminate|no&|' ${CHROOTDIR}/${TREE}/etc/esd.conf; \
	fi
ifeq ($(APPSGROUP),XFCE)
	sed -i 's/desktop=""/desktop="startxfce4"/' ${CHROOTDIR}/${TREE}/etc/sysconfig/desktop
endif
ifeq ($(APPSGROUP),FULL_GTK)
	sed -i 's/desktop=""/desktop="startxfce4"/' ${CHROOTDIR}/${TREE}/etc/sysconfig/desktop
endif

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
		rm -f ${CHROOTDIR}/${TREE}/etc/issue; \
		sed "s|VENDOR|${VENDOR}|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/parse_cmdline; \
		sed "s|FWLREL|$(shell ${FWLREL}) (${FWLCODENAME})|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/parse_cmdline; \
		sed "s|USERNAME|${FWLUSER}|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/parse_cmdline; \
		sed "s|USERPASS|${FWUSERPASS}|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/parse_cmdline; \
		sed "s|ROOTPASS|${FWROOTPASS}|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/parse_cmdline; \
		sed "s|SAVE_DIRS|${SAVEDIRS}|" -i ${CHROOTDIR}/${TREE}/usr/local/bin/configsave; \
	fi

live-base: checkroot
	echo "Include = /etc/pacman.d/janny" >> ${CHROOTDIR}/${TREE}/etc/pacman-g2.conf; \
	echo "[janny]" > ${CHROOTDIR}/${TREE}/etc/pacman.d/janny; \
	echo "Server = http://ftp.frugalware.org/pub/other/people/janny/fwlive/frugalware-i686/" >> ${CHROOTDIR}/${TREE}/etc/pacman.d/janny; \
	cp -a live-base ${CHROOTDIR}/${TREE}/tmp/
	mkdir -p ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/{lib,bin,etc}
	ln -sf configsave ${CHROOTDIR}/${TREE}/usr/local/bin/configrestore
	cp ${CHROOTDIR}/${TREE}/tmp/live-base/tools/* ${CHROOTDIR}/${TREE}/usr/local/bin/
	cp ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/linux/make_iso.sh ${CHROOTDIR}/${TREE}/usr/local/bin/
	chmod 777 ${CHROOTDIR}/${TREE}/usr/local/bin/*
	ln -sf make_iso.sh ${CHROOTDIR}/${TREE}/usr/local/bin/make_iso
	ln -sf install ${CHROOTDIR}/${TREE}/tmp/live-base/uninstall
	ln -sf ../tools/liblinuxlive ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/liblinuxlive
	cp ${CHROOTDIR}/${TREE}/sbin/blkid ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/sbin/blockdev ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/usr/share/busybox/bin/busybox ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/usr/bin/eject ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/usr/sbin/lspci ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/bin/
	cp ${CHROOTDIR}/${TREE}/lib/ld-$(shell ${GLIBCVER}).so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s ld-$(shell ${GLIBCVER}).so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/ld-linux.so.2
ifeq ($(ARCH),x86_64)
	ln -s lib ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib64
	ln -s ld-$(shell ${GLIBCVER}).so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/ld-linux-x86-64.so.2
endif
	cp ${CHROOTDIR}/${TREE}/lib/libblkid.so.1.0 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libblkid.so.1.0 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libblkid.so.1
	cp ${CHROOTDIR}/${TREE}/lib/libc-$(shell ${GLIBCVER}).so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libc-$(shell ${GLIBCVER}).so ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libc.so.6
	cp ${CHROOTDIR}/${TREE}/lib/libuuid.so.1.2 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libuuid.so.1.2 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libuuid.so.1
	cp ${CHROOTDIR}/${TREE}/usr/lib/libz.so.1.2.3 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/
	ln -s libz.so.1.2.3 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libz.so
	ln -s libz.so.1.2.3 ${CHROOTDIR}/${TREE}/tmp/live-base/initrd/rootfs/lib/libz.so.1
	cp ${CHROOTDIR}/${TREE}/usr/bin/mksquashfs ${CHROOTDIR}/${TREE}/tmp/live-base/tools/
	cp ${CHROOTDIR}/${TREE}/usr/bin/unsquashfs ${CHROOTDIR}/${TREE}/tmp/live-base/tools/
ifneq ($(ARCH),x86_64)
	cp ${CHROOTDIR}/${TREE}/boot/memtest.bin ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/
endif
ifeq ($(CONFIG_SETUP),y)
	cp ${SETUPKERNEL} ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/
	cp ${SETUPINITRD} ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/
endif
	cp ${CHROOTDIR}/${TREE}/usr/lib/grub/i386-pc/stage2_eltorito ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/
	cp ${CHROOTDIR}/${TREE}/boot/grub/message-fwlive ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/message
	cp menu.lst ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/
	sed -i "s|@GRUBTITLE@|${FWLSREL} ${FWREL}|" ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/menu.lst
ifeq ($(ARCH),x86_64)
	sed -i /[Mm]emtest/d ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/menu.lst
endif
ifeq ($(CONFIG_SETUP),y)
	echo "title Install Frugalware $(FWREL) - $(shell ${SETUPKERNELVER})" >> ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/menu.lst
	echo "	kernel /boot/vmlinuz-$(shell ${SETUPKERNELVER}) initrd=initrd-$(ARCH).img.gz load_ramdisk=1 prompt_ramdisk=0 ramdisk_size=$(shell ${SETUPINITRDSIZE}) rw root=/dev/ram quiet vga=791" >> ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/menu.lst
	echo "	initrd /boot/initrd-$(ARCH).img.gz" >> ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/boot/grub/menu.lst
endif
	sed -i 's/`uname -r`/$(shell ${KERNVER})/' ${CHROOTDIR}/${TREE}/tmp/live-base/.config
	sed -i "s|linuxcd|${FWLHOST}|" ${CHROOTDIR}/${TREE}/tmp/live-base/.config
	sed -i "s|Live|$(shell ${FWLREL}) (${FWLCODENAME})|" ${CHROOTDIR}/${TREE}/tmp/live-base/cd-root/linux/make_iso.sh
	sed -i "s|KERNEL=.*|KERNEL=\"$(shell ${KERNVER})\"|" ${CHROOTDIR}/${TREE}/tmp/live-base/.config

hacking-kdmrc: checkroot
	if [ ${APPSGROUP} == "KDE" ] || [ ${APPSGROUP} == "FULL" ] ; then \
		sed -i "s|RebootCmd=/sbin/reboot -n|RebootCmd=/sbin/reboot|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|AutoReLogin=false|AutoReLogin=true|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|AllowShutdown=Root|AllowShutdown=All|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|NoPassEnable=false|NoPassEnable=true|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|NoPassUsers=|NoPassUsers=fwlive|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|NumLock=On|NumLock=Off|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|AutoLoginEnable=false|AutoLoginEnable=true|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|#AutoLoginUser=foo|AutoLoginUser=fwlive|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|PreselectUser=Previous|PreselectUser=None|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i "s|FocusPasswd=false|FocusPasswd=true|" ${CHROOTDIR}/${TREE}/usr/share/config/kdm/kdmrc; \
		sed -i 's/desktop=""/desktop="\/usr\/bin\/kdm -nodaemon"/' ${CHROOTDIR}/${TREE}/etc/sysconfig/desktop; \
	fi

create: chroot-mount create-iso chroot-umount
	echo "./${ISONAME} created."

create-iso: checkroot
	chroot ${CHROOTDIR}/${TREE} /sbin/depmod -ae -v $(shell ${KERNVER}) &>/dev/null
	chroot ${CHROOTDIR}/${TREE} sh /tmp/live-base/build
	mv ${CHROOTDIR}/${TREE}/tmp/livecd.iso ./${ISONAME}
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
	if [ ! $(shell mount|grep -o ${CHROOTDIR}/${TREE}/var/cache/pacman-g2) ] ; then \
		mount -o bind /var/cache/pacman-g2 ${CHROOTDIR}/${TREE}/var/cache/pacman-g2 ; \
	fi

chroot-umount: checkroot
	umount ${CHROOTDIR}/${TREE}/{proc,sys,dev} &>/dev/null

cache-umount: checkroot
	umount ${CHROOTDIR}/${TREE}/var/cache/pacman-g2 &>/dev/null

clean:
	rm -f ${ISONAME} crypt_fwlive parse_cmdline xorg.conf ${PACCONF}

distclean: checkroot clean
	${MAKE} -C po distclean
	rm -rf ${CHROOTDIR}/${TREE}
