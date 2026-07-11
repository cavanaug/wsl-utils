PREFIX  ?= /usr/local
DESTDIR ?=

BINDIR      := $(DESTDIR)$(PREFIX)/bin
DATADIR     := $(DESTDIR)$(PREFIX)/share/wslutil

CORE_SCRIPTS := \
	wslutil wslutil-config wslutil-doctor wslutil-setup wslutil-uptime \
	win-run win-open win-browser win-copy win-paste win-utf8 \
	wslpath-drive

.PHONY: install uninstall check-deps

install:
	install -d $(BINDIR) $(DATADIR)/config $(DATADIR)/env $(DATADIR)/lib
	for f in $(CORE_SCRIPTS); do \
		install -m 0755 bin/$$f $(BINDIR)/$$f; \
	done
	ln -sf win-browser $(BINDIR)/wslview
	cp -R config/. $(DATADIR)/config/
	cp -R env/. $(DATADIR)/env/
	install -m 0644 lib/wslutil-paths.sh $(DATADIR)/lib/wslutil-paths.sh
	install -m 0644 VERSION $(DATADIR)/VERSION

uninstall:
	for f in $(CORE_SCRIPTS) wslview; do \
		rm -f $(BINDIR)/$$f; \
	done
	rm -rf $(DATADIR)/config $(DATADIR)/env $(DATADIR)/lib
	rm -f $(DATADIR)/VERSION
	# do NOT remove $(DATADIR)/bin (shims) or $(DATADIR) itself

check-deps:
	@missing=0; \
	for c in yq crudini; do \
		if ! command -v $$c >/dev/null 2>&1; then \
			echo "missing: $$c"; missing=1; \
		else \
			echo "ok: $$c"; \
		fi; \
	done; \
	exit $$missing
