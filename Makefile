#
# Makefile for Brazilian Portuguese Python Documentation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  based on: https://github.com/python/python-docs-fr/blob/3.8/Makefile
#

# Configuration

CPYTHON_PATH        := ../cpython
BRANCH              := 3.8
MERGEBRANCHES       := 3.7 3.6 2.7
LANGUAGE_TEAM       := python-docs-pt-br
LANGUAGE            := pt_BR

# Internal variables

UPSTREAM            := https://github.com/python/cpython
VENV                := $(shell realpath ./venv)
PYTHON              := $(shell which python3)
WORKDIRS            := $(VENV)/workdirs
CPYTHON_WORKDIR     := $(WORKDIRS)/cpython
LOCALE_DIR          := $(WORKDIRS)/locale
JOBS                := auto
SPHINXERRORHANDLING := "-W"
TRANSIFEX_PROJECT   := python-newest
POSPELL_TMP_DIR     := .pospell


.PHONY: help
help:
	@echo "Please use 'make <target>' where <target> is one of:"
	@echo " build        Build an local version in html, with warnings as errors"
	@echo " push         Update translations and Transifex config in the repository"
	@echo " pull         Download translations from Transifex; calls 'venv'"
	@echo " tx-config    Recreate an up-to-date project .tx/config; calls 'pot'"
	@echo " pot          Create/Update POT files from source files"
	@echo " serve        Serve a built documentation on http://localhost:8000"
	@echo " spell        Check spelling, storing output in $(POSPELL_TMP_DIR)"
	@echo " merge        Merge $(BRANCH) branch's .po files into: $(MERGEBRANCHES)"
	@echo ""


# build: build the documentation using the translation files currently available
#        at the moment. For most up-to-date docs, run "tx-config" and "pull"
#        before this. If passing SPHINXERRORHANDLING='', warnings will not be
#        treated as errors, which is good to skip simple Sphinx syntax mistakes.
.PHONY: build
build: setup
	@echo "Building Python $(BRANCH) Documentation ..."
	@$(MAKE) -C $(CPYTHON_WORKDIR)/Doc/              \
		VENVDIR=$(CPYTHON_WORKDIR)/Doc/venv         \
		PYTHON=$(PYTHON)                            \
		SPHINXERRORHANDLING=$(SPHINXERRORHANDLING)  \
		SPHINXOPTS='-q --keep-going -j$(JOBS)       \
			-D locale_dirs=$(LOCALE_DIR)            \
			-D language=$(LANGUAGE)                 \
			-D gettext_compact=0                    \
			-D latex_engine=xelatex                 \
			-D latex_elements.inputenc=             \
			-D latex_elements.fontenc='             \
		html
		
	@echo "Success! Open file://$(CPYTHON_WORKDIR)/Doc/build/html/index.html, " \
		  "or run 'make serve' to see them in http://localhost:8000";


# push: push new translation files and Transifex config files to repository,
#       if any. Do nothing if there is no file changes. If GITHUB_TOKEN is set,
#       then assumes we are in GitHub Actions, requiring different push args
.PHONY: push
push:
	@if ! git status -s | egrep '\.po|\.tx/config'; then                    \
		echo "Nothing to commit";                                           \
		exit 0;                                                             \
	else                                                                    \
		git add *.po **/*.po .tx/config;                                    \
		git commit -m 'Update translations from Transifex';                 \
		if [ $(GITHUB_TOKEN) != "" ]; then                                  \
			header="$(echo -n token:"$(GITHUB_TOKEN)" | base64)";           \
			git -c http.extraheader="AUTHORIZATION: basic $(header)" push;  \
		else                                                                \
			git push;                                                       \
		fi;                                                                 \
	fi


# pull: Download translations files from Transifex, and apply line wrapping.
#       For downloading new translation files, first run "tx-config" target
#       to update the translation file mapping.
.PHONY: pull
pull: venv
	@$(VENV)/bin/tx pull --force --language=$(LANGUAGE) --parallel
	@$(VENV)/bin/powrap --quiet *.po **/*.po


# tx-config: After running "pot", create a new Transifex config file by
#            reading pot files generated, then tweak this config file to
#            LANGUAGE.
.PHONY: tx-config
tx-config: pot
	@cd $(CPYTHON_WORKDIR)/Doc/locales;                 \
	rm -rf .tx;                                         \
	$(VENV)/bin/sphinx-intl create-txconfig;            \
	$(VENV)/bin/sphinx-intl update-txconfig-resources   \
	    --transifex-project-name=$(TRANSIFEX_PROJECT)   \
	    --locale-dir .                                  \
	    --pot-dir pot;
	
	@mkdir -p .tx
	@sed $(CPYTHON_WORKDIR)/Doc/locales/.tx/config    \
	    -e '/^source_file/d'                          \
	    -e 's|<lang>/LC_MESSAGES/||'                  \
	    -e "s|^file_filter|trans.$(LANGUAGE)|"        \
	    > .tx/config


# pot: After running "setup" target, run a cpython Makefile's target
#      to generate .pot files under $(CPYTHON_WORKDIR)/Doc/locales/pot
.PHONY: pot
pot: setup
	@$(MAKE) -C $(CPYTHON_WORKDIR)/Doc/         \
		VENVDIR=$(CPYTHON_WORKDIR)/Doc/venv     \
		PYTHON=$(PYTHON)                        \
		ALLSPHINXOPTS='-E -b gettext            \
			-D gettext_compact=0                \
			-d build/.doctrees .                \
			locales/pot'                        \
		build


# setup: After running "venv" target, prepare that virtual environment with
#        a local clone of cpython repository and the translation files.
#        If the directories exists, only update the cpython repository and
#        the translation files copy which could have new/updated files.
.PHONY: setup
setup: venv
	@if ! [ -d $(CPYTHON_PATH) ]; then                                      \
		echo "CPython repo not found; cloning ...";                         \
		git clone --depth 1 --branch $(BRANCH) $(UPSTREAM) $(CPYTHON_PATH); \
	else                                                                    \
		echo "CPython repo found; updating ...";                            \
		git -C $(CPYTHON_PATH) pull --rebase;                               \
	fi
	
	@if ! [ -d $(CPYTHON_WORKDIR) ]; then                                   \
		echo "Setting up CPython repo in workdir ...";                      \
		rm -fr $(WORKDIRS);                                                 \
		mkdir -p $(WORKDIRS);                                               \
		git clone $(CPYTHON_PATH) $(CPYTHON_WORKDIR);                       \
		$(MAKE) -C $(CPYTHON_WORKDIR)/Doc                                   \
			VENVDIR=$(CPYTHON_WORKDIR)/Doc/venv                             \
			PYTHON=$(PYTHON) venv;                                          \
	else                                                                    \
	    echo "CPython repo already ready in workdir";                       \
	fi
	
	@echo "Setting up translation files in workdir ..."
	@if ! [ -d $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/ ]; then               \
		mkdir -p $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/;                    \
	fi
	@cp --parents *.po **/*.po $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/


# venv: create a virtual environment which will be used by almost every
#       other target of this script
.PHONY: venv
venv:
	@echo "Setting up $(LANGUAGE_TEAM)'s virtual environment ...";
	@if [ ! -d $(VENV) ]; then                                           \
		$(PYTHON) -m venv --prompt $(LANGUAGE_TEAM) $(VENV);             \
	fi
	
	@$(VENV)/bin/python -m pip install -q -r requirements.txt 2> $(VENV)/pip-install.log
	
	@if grep -q 'pip install --upgrade pip' $(VENV)/pip-install.log; then \
		$(VENV)/bin/pip install -q --upgrade pip;                         \
	fi


# serve: serve the documentation in a simple local web server, using cpython
#        Makefile's "serve" target. Run "build" before using this target.
.PHONY: serve
serve:
	@$(MAKE) -C $(CPYTHON_WORKDIR)/Doc serve


# list files for spellchecking
SRCS := $(wildcard *.po **/*.po)
DESTS = $(addprefix $(POSPELL_TMP_DIR)/out/,$(patsubst %.po,%.txt,$(SRCS)))


# spell: run spell checking tool in all po files listed in SRCS variable,
#        storing the output in text files DESTS for proofreading.  The
#        DESTS target run the spellchecking, while the typos.txt target
#        gather all reported issues in one file, sorted without redundancy
.PHONY: spell
spell: venv $(DESTS) $(POSPELL_TMP_DIR)/typos.txt

$(POSPELL_TMP_DIR)/out/%.txt: %.po dict
	@echo "Checking $< ..."
	@mkdir -p $(@D)
	@$(VENV)/bin/pospell -l $(LANGUAGE) -p dict $< > $@ || true

$(POSPELL_TMP_DIR)/typos.txt:
	@echo "Gathering all typos in $(POSPELL_TMP_DIR)/typos.txt ..."
	@cut -d: -f3- $(DESTS) | sort -u > $@


# merge: merge translations from BRANCH (Python version currently aim of
#        translation) into each branch listed by MERGEBRANCHES (branches
#        of older Python versions) so that older versions of the Python
#        docs make at least some use the latest translations, if possible.
#        After merging, git-push merged files (if any) to the target branch.
.PHONY: merge
merge: venv $(MERGEBRANCHES)

$(MERGEBRANCHES):
	@echo "Merging translations from $(BRANCH) branch into $@ ..."
	@$(VENV)/bin/pomerge --from-files *.po **/*.po
	@git checkout $@
	@$(VENV)/bin/pomerge --no-overwrite --to-files *.po **/*.po
	@$(VENV)/bin/powrap --modified *.po **/*.po
	@if git status -s | egrep '\.po'; then                                  \
		git add *.po **/*.po;                                               \
		git commit -m "pomerge from $(BRANCH) branch into @";               \
		git push;                                                           \
	fi
	@git checkout $(BRANCH)


# clean: remove all .mo files and the venv directory that may exist and
#        could have been created by the actions in other targets of this script
.PHONY: clean
clean:
	rm -fr $(VENV)
	rm -rf $(POSPELL_TMP_DIR)
	find -name '*.mo' -delete
