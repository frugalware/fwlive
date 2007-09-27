top_srcdir =
PO_DIR=~/git/translations/po
LANGS = $(shell ls $(PO_DIR)/fwlive)

pos:
	[ -d $(PO_DIR) ]
	for i in $(LANGS); \
	do \
		cp $(PO_DIR)/fwlive/$$i/fwlive.po $$i.po; \
		if ! msgfmt -c --statistics -o $$i.gmo $$i.po; then \
			echo "WARNING: $$i.po will break your build!"; \
		fi; \
	done

mos:
	for i in $(wildcard *.po); do \
		echo -n "$$i: "; \
		msgfmt -c --statistics -o $(CHROOTDIR)/$(TREE)/usr/share/locale/`basename $$i .po`/LC_MESSAGES/fwlive.mo $$i; \
	done

pot: intltool-extract
	for i in `cat POTFILES.in`; do \
		ln -s `basename $$i .sh` ../$$i; \
	done
	intltool-update --pot --gettext-package=fwlive
	for i in `cat POTFILES.in`; do \
		rm ../$$i; \
	done

intltool-extract:
	cp /usr/bin/intltool-extract ./

update-po: pot
	for lang in $(LANGS); do \
		if msgmerge $$lang.po fwlive.pot -o $$lang.new.po; then \
			mv -f $$lang.new.po $$lang.po; \
		else \
			echo "msgmerge for $$cat failed!"; \
			rm -f $$lang.new.po; \
		fi; \
	done

distclean:
	rm -f intltool-extract *.pot *.po *.gmo
