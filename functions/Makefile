#MAKEFILE for installing functions

FUNPATH := $(HOME)/.local/functions


SCRIPTS = nohistory tlabel
TARGETS = $(addprefix $(FUNPATH)/,$(SCRIPTS))
SOURCES = $(addsuffix .sh,$(SCRIPTS))

SHELL = /bin/bash
PWD = $(shell pwd)



.PHONY:  info help uninstall
default: install



install: $(TARGETS)



$(FUNPATH)/% :  %.sh  $(FUNPATH)
	cp $(<) $(@)
	chmod +x $(@)


$(FUNPATH):
	@echo "" >> $(HOME)/.bashrc
	@echo "#Load Functions" >> $(HOME)/.bashrc
	@echo "for f in \$$(find $(FUNPATH) -type f | grep -vE '/\.[a-zA-Z0-9_.-]+\$$'); do" >> $(HOME)/.bashrc
	@echo "  source \$${f}" >> $(HOME)/.bashrc
	@echo "done" >> $(HOME)/.bashrc
	mkdir -p $(FUNPATH)



info:
	$(info Shell: $(SHELL))
	$(info PWD: $(PWD))
	$(info Fun Path: $(FUNPATH))
	$(info Scripts: $(SCRIPTS))
	$(info Sources: $(SOURCES))
	$(info Targets: $(TARGETS))
	

help:
	@ echo "Invoked help:"
	@ echo "  install            -  Install functions into Local path."
	@ echo "  uninstall          -  Remove scripts from Local path."
	@ echo ""
	@ echo "  info               -  Show info about all config."
	@ echo ""
	@ echo "All targets require sudo to execute."
