ifeq ($(wildcard Latex_Templates/core/build/docbuild.mk),)
$(error Latex_Templates not checked out: see CONTRIBUTING.md, Documents (LaTeX))
endif
include Latex_Templates/core/build/docbuild.mk

# Settings (Latex_Templates/core/build/README.md), paths relative to this Makefile; commented lines show defaults:
DOCBUILD_SRC := software/Source_Documentation
DOCBUILD_OUT := software/PDF_Documentation
DOCBUILD_RELEASE_TAGS := false
# DOCBUILD_TAG_PREFIX :=
# DOCBUILD_DIFF := true
# DOCBUILD_TEXINPUTS :=
# PYTHON := python3

# Groups of this repo's docs, e.g. make general:
# general:
# 	@$(MAKE) --no-print-directory build TDD_General RASD_General
