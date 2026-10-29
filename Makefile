#MAKEFILE for installing tools

LOCALBINPATH := $(HOME)/.local/bin
BINPATH := /bin


SCRIPTS = checkip checknet clize exe2iface lscom tcpdump2 watch2
TARGETS = $(addprefix $(BINPATH)/,$(SCRIPTS))
SOURCES = $(addsuffix .sh,$(SCRIPTS))

SHELL = /bin/bash
PWD = $(shell pwd)



.PHONY:  info help uninstall
default: install



install: $(TARGETS)


$(BINPATH)/% :  %.sh
	cp $(<) $(@)
	chmod +x $(@)



uninstall:
	@if [ -n "$(wildcard $(TARGETS))" ]; then \
		echo "Removing scripts from local bin"; \
		echo "rm $(wildcard $(TARGETS))";\
		rm $(wildcard $(TARGETS));\
	else \
		echo "No installed scripts found"; \
	fi



install-local:
	$(MAKE) BINPATH="$(LOCALBINPATH)" install

uninstall-local:
	$(MAKE) BINPATH="$(LOCALBINPATH)" uninstall

install-functions:
	$(MAKE) -C functions install


info:
	$(info Shell: $(SHELL))
	$(info PWD: $(PWD))
	$(info Bin Path: $(BINPATH))
	$(info LocalBin: $(LOCALBINPATH))
	$(info Scripts: $(SCRIPTS))
	$(info Sources: $(SOURCES))
	$(info Targets: $(TARGETS))




help:
	@ echo "Invoked help:"
	@ echo "  install            -  Install scripts on BIN path."
	@ echo "  uninstall          -  Remove scripts from BIN path."
	@ echo ""
	@ echo "  install-local      -  Install scripts on local BIN path."
	@ echo "  uninstall-local    -  Remove scripts from local BIN path."
	@ echo ""
	@ echo "  install-functions  -  Install functions"
	@ echo ""
	@ echo "  info               -  Show info about all config."
	@ echo ""
	@ echo "All targets require sudo to execute."
