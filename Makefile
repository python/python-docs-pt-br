#
# Makefile for Brazilian Portuguese Python Documentation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  based on: https://github.com/python/python-docs-fr/blob/3.8/Makefile
#

# Configuration

CPYTHON_PATH    := ../cpython
BRANCH          := 3.8
LANGUAGE_TEAM   := python-docs-pt-br
LANGUAGE        := pt_BR

# Internal variables

UPSTREAM        := https://github.com/python/cpython
VENV            := $(shell realpath ./venv)
PYTHON          := $(shell which python3)
POSPELL_TMP_DIR := .pospell
WORKDIRS        := $(VENV)/workdirs
CPYTHON_WORKDIR := $(WORKDIRS)/cpython
LOCALE_DIR      := $(WORKDIRS)/locale
JOBS            := auto


.PHONY: help
help:
	@echo "Please use 'make <target>' where <target> is one of"
	@echo " build       To build an local version in html"
	@echo " update      To download and commit translations from Transifex"
	@echo " serve       To serve the documentation on the localhost (8000)"
	@echo " todo        To list remaining translations to do"
	@echo " fuzzy       To find fuzzy strings"
	@echo " spell       To check for spelling"
	@echo " wrap        To check for wrapping"
	@echo " verifs      To check for correctness (call spell and wrap)"
	@echo " progress    To compute current translated percentage"


.PHONY: build
build: setup
	$(MAKE) -C $(CPYTHON_WORKDIR)/Doc/          \
		VENVDIR=$(CPYTHON_WORKDIR)/Doc/venv     \
		PYTHON=$(PYTHON)                        \
		SPHINXOPTS='-qW --keep-going -j$(JOBS)  \
			-D locale_dirs=$(LOCALE_DIR)        \
			-D language=$(LANGUAGE)             \
			-D gettext_compact=0                \
			-D latex_engine=xelatex             \
			-D latex_elements.inputenc=         \
			-D latex_elements.fontenc='         \
		html;
		
		@echo "Build success, open file://$(CPYTHON_WORKDIR)/Doc/build/html/index.html, " \
		      "or run 'make serve' to see them in http://localhost:8000";


.PHONY: setup
setup: venv
	# Setup the main clone
	if ! [ -d $(CPYTHON_PATH) ]; then                                       \
		git clone --depth 1 --branch $(BRANCH) $(UPSTREAM) $(CPYTHON_PATH); \
	else                                                                    \
		git -C $(CPYTHON_PATH) pull --rebase;                               \
	fi
	
	# Setup the current work directory
	if ! [ -d $(CPYTHON_WORKDIR) ]; then                                    \
		rm -fr $(WORKDIRS);                                                 \
		mkdir -p $(WORKDIRS);                                               \
		git clone $(CPYTHON_PATH) $(CPYTHON_WORKDIR);                       \
		$(MAKE) -C $(CPYTHON_WORKDIR)/Doc                                   \
			VENVDIR=$(CPYTHON_WORKDIR)/Doc/venv                             \
			PYTHON=$(PYTHON) venv;                                          \
	fi
	
	# Setup translation files
	if ! [ -d $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/ ]; then                \
		mkdir -p $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/;                    \
	fi;                                                                     \
	cp --parents *.po */*.po $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/         \


.PHONY: venv
venv:
	if [ ! -d $(VENV) ]; then                                            \
		$(PYTHON) -m venv --prompt $(LANGUAGE_TEAM) $(VENV);             \
	fi
	
	$(VENV)/bin/python -m pip install -q -r requirements.txt 2> $(VENV)/pip-install.log
	
	if grep -q 'pip install --upgrade pip' $(VENV)/pip-install.log; then \
		$(VENV)/bin/pip install -q --upgrade pip;                        \
	fi


.PHONY: serve
serve:
	$(MAKE) -C $(CPYTHON_WORKDIR)/Doc serve


.PHONY: update
update:
	tx pull -f
	git add -u *.po **/*.po
	git commit -m 'make update'
	git push


.PHONY: progress
progress:
	@$(PYTHON) -c 'import sys; print("{:.1%}".format(int(sys.argv[1]) / int(sys.argv[2])))' \
	$(shell msgcat *.po */*.po | msgattrib --translated | grep -c '^msgid') \
	$(shell msgcat *.po */*.po | grep -c '^msgid')


.PHONY: todo
todo: venv
	$(VENV)/bin/potodo


.PHONY: wrap
wrap: venv
	$(VENV)/bin/powrap --check --quiet *.po **/*.po


SRCS = $(shell git log --name-only --pretty='format:' -1 $(BRANCH) | grep '.po$$')
# foo/bar.po => $(POSPELL_TMP_DIR)/foo/bar.po.out
DESTS = $(addprefix $(POSPELL_TMP_DIR)/,$(addsuffix .out,$(SRCS)))

# TODO: This is checking only files from last commit; change to all files?
.PHONY: spell
spell: venv $(DESTS)


# TODO: Create customized dictionary to be used here, and then enable 'dict'
#$(POSPELL_TMP_DIR)/%.po.out: %.po dict
$(POSPELL_TMP_DIR)/%.po.out: %.po
	@echo "Checking $<..."
	@mkdir -p $(@D)
	@$(VENV)/bin/pospell -l $(LANGUAGE) $< && touch $@
	#@$(VENV)/bin/pospell -p dict -l $(LANGUAGE) $< && touch $@


.PHONY: fuzzy
fuzzy: venv
	$(VENV)/bin/potodo -f


.PHONY: verifs
verifs: wrap spell


.PHONY: clean
clean:
	rm -fr $(VENV) $(POSPELL_TMP_DIR)
	find -name '*.mo' -delete
