#
# Makefile for Brazilian Portuguese Python Documentation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  based on: https://github.com/python/python-docs-fr/blob/3.8/Makefile
#

#################
# Configuration

# Read environment variables from file to keep this clean move version
# changes elsewhere
include .env

# Force the use of Bash
SHELL=/bin/bash

# Time of starting this run
NOW                    := $(shell date +'%Y%m%-d-%H%M%Z')

# Force realpath, not relative one
override CPYTHON_DIR   := $(shell realpath $(CPYTHON_DIR))

override LOGS_DIR      := $(shell realpath $(LOGS_DIR))

override VENV_DIR      := $(shell realpath $(VENV_DIR))
#
#################

.PHONY: build clean help htmlview lint merge pot pull push setup spell tx-config tx-install venv

help:
	@echo "Please use 'make <target>' where <target> is one of:"
	@echo " build        Build an local version in html; deps: 'setup'"
	@echo " push         Commit and push translations; no deps"
	@echo " pull         Download translations from Transifex; deps: 'tx-config'"
	@echo " tx-config    Regenerate Transifex config; deps: 'pot' and 'tx-install'"
	@echo " tx-install   Install Transifex CLI client; deps: no deps"
	@echo " pot          Regenerate POT files from sources; deps: 'setup'"
	@echo " htmlview     View docs in a web browser; deps: build"
	@echo " spell        Check spelling, storing output in $(POSPELL_TMP_DIR)"
	@echo " lint         Do some linting in PO file's Sphinx syntax. deps: 'venv'"
	@echo " merge        Merge $(BRANCH) branch's .po files into older branches"
	@echo "                Defaults overwrite in: $(BUGFIXBRANCH)"
	@echo "                and NOT overwrite in: $(OLDERBRANCHES)"
	@echo " clean        Do some house cleaning"
	@echo ""


# build: build the documentation using the translation files currently available
#        at the moment. For most up-to-date docs, run "tx-config" and "pull"
#        before this. If passing SPHINXERRORHANDLING='', warnings will not be
#        treated as errors, which is good to skip simple Sphinx syntax mistakes.
build: setup
	@mkdir -p "$(CPYTHON_DIR)/$(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/"
	@cp --parents *.po **/*.po "$(CPYTHON_DIR)/$(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES/"
	@echo "Building Python $(BRANCH) Documentation in $(LANGUAGE) ..."
	@mkdir -p "$(LOGS_DIR)/build"
	@$(MAKE) -C $(CPYTHON_DIR)/Doc/ \
	    PYTHON=$(PYTHON) \
	    SPHINXERRORHANDLING=$(SPHINXERRORHANDLING) \
	    SPHINXOPTS="--keep-going \
	        -D gettext_compact=0 \
	        -D language=$(LANGUAGE) \
	        -D latex_engine=xelatex \
	        -D latex_elements.inputenc= \
	        -D latex_elements.fontenc=" \
	    html \
	    2> >(tee -a $(LOGS_DIR)/build/err-$(NOW).txt >&2)


# push: Commit and push translation files and Transifex config file to repo.
#       First it git-adds tracked file that doesn't exclusively match changes
#       in POT-Creation-Date header field. Then it git-adds untracked PO files
#       that might have been created in the update process, and the Transifex
#       configuration. Finally, only commit and push only if any file was
#       git-added (staged); otherwise, it does nothing.
#       The MSG variable has a default commit message, but one can override it
#       e.g. make push MSG='my message'
push:
	@git diff -I'^"POT-Creation-Date: ' --numstat *.po **/*.po | cut -f3 | xargs -r git add
	@git add $(shell git ls-files -o *.po **/*.po) .tx/config
	@git diff-index --cached --quiet HEAD || \
	{ git commit -m "Update translations from Transifex" && git push; }


# pull: Download translations files from Transifex, and apply line wrapping.
#       For downloading new translation files, first run "tx-config" target
#       to update the translation file mapping.
pull: tx-config
	@"$(TX_CLI_DIR)/tx" pull -l $(LANGUAGE) -t -f --use-git-timestamps
	@"$(VENV_DIR)/bin/powrap" --quiet *.po **/*.po


# tx-config: Generate a new Transifex configuration file by reading
#            the pot files generated by 'pot' target. The file is
#            created in $(LOCALE_DIR)/.tx/config, and then is tweaked
#            to fit the language's needs and then placed in .tx/config
#            at the project's root directory.
tx-config: TRANSIFEX_PROJECT := python-newest
tx-config: pot tx-install
	@cd $(CPYTHON_DIR)/$(LOCALE_DIR); \
	rm -rf .tx; \
	"$(VENV_DIR)/bin/sphinx-intl" create-txconfig; \
	"$(VENV_DIR)/bin/sphinx-intl" update-txconfig-resources \
	    --transifex-organization-name python-doc \
	    --transifex-project-name=$(TRANSIFEX_PROJECT) \
	    --locale-dir . \
	    --pot-dir pot
	@mkdir -p .tx
	@sed $(CPYTHON_DIR)/$(LOCALE_DIR)/.tx/config \
	    -e "s|^file_filter *= .*|&\nx&|;" \
	    -e "s|^source_file *= pot/|source_file  = $(LOCALE_RELATIVE)/pot/|" \
	    > .tx/config
	@sed -i .tx/config \
	    -e "s|^xfile_filter *= ./<lang>/LC_MESSAGES/|trans.$(LANGUAGE)  = |;"


# tx-install: Install Transifex CLI client if not installed yet. Installs
#             the TX_CLI_VERSION version into TX_CLI_DIR directory. If
#             TX_CLI_VERSION not provided, uses the latest one.
tx-install: URL := https://raw.githubusercontent.com/transifex/cli/master/install.sh
tx-install:
	@if [ ! -x "$(TX_CLI_DIR)/tx" ]; then \
	    echo "Transifex TX Client not found, installing ..."; \
	    cd "$(TX_CLI_DIR)"; \
	    if [ -n "v$(TX_CLI_VERSION)" ]; then \
	        curl -s -o- $(URL) | bash -s -- v$(TX_CLI_VERSION); \
	    else \
	        curl -s -o- $(URL) | bash; \
	    fi; \
	fi


# pot: After running "setup" target, run sphinx-build's gettext target
#      to generate .pot files under $(CPYTHON_DIR)/Doc/locales/pot.
pot: setup
	@$(MAKE) -C $(CPYTHON_DIR)/Doc/ \
	    VENVDIR=./venv \
	    PYTHON=$(PYTHON) \
	    ALLSPHINXOPTS='-E \
	        -b gettext \
	        -D gettext_compact=0 \
	        -d build/.doctrees \
	        . $(CPYTHON_DIR)/$(LOCALE_DIR)/pot' \
	    build


# setup: After running "venv" target, prepare that virtual environment with
#        a local clone of cpython repository and the translation files.
#        If the directories exists, only update the cpython repository and
#        the translation files copy which could have new/updated files.
setup: CPYTHON_URL := https://github.com/python/cpython
setup: venv
	@if [ -z "$(BRANCH)" ]; then \
	    echo "BRANCH is empty, should have git-branch. Unable to continue."; \
	    exit 1; \
	fi
	
	@if ! [ -d "$(CPYTHON_DIR)" ]; then \
	    echo "CPython repo not found; cloning ..."; \
	    git clone --depth 1 --no-single-branch $(CPYTHON_URL) $(CPYTHON_DIR); \
	    git -C "$(CPYTHON_DIR)" checkout $(BRANCH); \
	else \
	    echo "CPython repo found; updating ..."; \
	    git -C "$(CPYTHON_DIR)" checkout $(BRANCH); \
	    git -C "$(CPYTHON_DIR)" pull --rebase; \
	fi
	
	@echo "Creating CPython's documentation virtual environment ..."
	@if [ ! -d "$(CPYTHON_DIR)/Doc/venv" ]; then \
	    $(MAKE) -C "$(CPYTHON_DIR)/Doc" PYTHON=$(PYTHON) venv; \
	fi


# venv: create a virtual environment which will be used by almost every
#       other target of this script. CPython specific packages are installed
#       in there specific venv (see 'setup' target).
venv:
	@if [ ! -d "$(VENV_DIR)" ]; then \
	    echo "Setting up language team's virtual environment ..."; \
	    "$(PYTHON)" -m venv "$(VENV_DIR)"; \
	    "$(VENV_DIR)/bin/python" -m pip install --upgrade pip; \
	    mkdir -p "$(LOGS_DIR)"; \
	    "$(VENV_DIR)/bin/pip" install --requirement requirements.txt \
	        --log "$(LOGS_DIR)/venv-$(NOW).txt"; \
	fi


# htmlview: View the documentation locally, using Makefile's "htmlview" target.
#           Run "build" before using this target.
htmlview: build
	@INDEX="$(CPYTHON_DIR)/Doc/build/html/index.html"; \
	"$(PYTHON)" -c "import os, webbrowser; \
	webbrowser.open('file://' + os.path.realpath('$$INDEX'))"


# spell: run spell checking tool in all po files listed in SRCS variable,
#        storing the output in text files DESTS for proofreading.  The
#        DESTS target run the spellchecking, while the typos.txt target
#        gather all reported issues in one file, sorted without redundancy.
SRCS := $(wildcard *.po **/*.po)
DESTS := $(addprefix $(LOGS_DIR)/pospell-$(NOW)/out/,$(patsubst %.po,%.txt,$(SRCS)))
spell: venv $(DESTS) $(LOGS_DIR)/pospell-$(NOW)/all.txt

$(LOGS_DIR)/pospell-$(NOW)/out/%.txt: %.po dict
	@echo "Checking $< ..."
	@mkdir -p $(@D)
	@$(VENV_DIR)/bin/pospell -l "$(LANGUAGE)" -p dict $< > $@ || true

$(LOGS_DIR)/pospell-$(NOW)/all.txt:
	@echo "Gathering all typos in $(LOGS_DIR)/pospell-$(NOW)/all.txt ..."
	@cut -d: -f3- $(DESTS) | sort -u > $@


# merge: Merge translations from BRANCH (Python version currently aim of
#        translation) into each branch listed by BUGFIXBRANCH and
#        OLDERBRANCHES (branches of older Python versions) so that older
#        versions of the Python Docs try make at least some use of the latest
#        translations. OLDERBRANCHES has '--no-overwrite' flag so it does not
#        overwrite translated strings, preserving history.
#        After merging, only commit and push only if any file was git-added
#        (staged) to the target branch; otherwise, it does nothing.
merge: venv $(BUGFIXBRANCH) $(OLDERBRANCHES)

$(OLDERBRANCHES):  OVERWRITEFLAG = --no-overwrite
$(BUGFIXBRANCH) $(OLDERBRANCHES):
	@if [[ $@ == $(BRANCH) ]]; then \
	    echo "Ignoring attempt to pomerge '$(BRANCH)' into itself."; \
	else \
	    echo "Merging translations from $(BRANCH) branch into $@ ..."; \
	    $(VENV_DIR)/bin/pomerge --from-files *.po **/*.po; \
	    git checkout $@; \
	    $(VENV_DIR)/bin/pomerge $(OVERWRITEFLAG) --to-files *.po **/*.po; \
	    $(VENV_DIR)/bin/powrap --modified *.po **/*.po; \
	    git add -u; \
	    if [ -n "$(git diff --name-only --cached)" ]; then \
	        git commit -m $(MSG); \
	        git push; \
	    else \
	        echo 'Nothing to commit'; \
	    fi; \
	    git checkout $(BRANCH); \
	fi


# lint: Report reStructuredText syntax errors in the translation files
lint: venv
	@mkdir -p "$(LOGS_DIR)"
	@$(VENV_DIR)/bin/sphinx-lint *.po **/*.po |& \
	    tee -a $(LOGS_DIR)/lint-$(NOW).txt || true
	@echo "Lint output stored in $(LOGS_DIR)/lint-$(NOW).txt"


# clean: remove all .mo files and the venv directory that may exist and could
#        have been created by the actions in other targets of this script.
clean:
	rm -rf "$(VENV_DIR)"
	rm -rf "$(CPYTHON_DIR)/$(LOCALE_DIR)"
	[ -d "$(CPYTHON_DIR)" ] && $(MAKE) -C "$(CPYTHON_DIR)/Doc" clean-venv
