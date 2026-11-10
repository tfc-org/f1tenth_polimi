ifeq ($(wildcard Latex_Templates/core/build/docbuild.mk),)
$(error Latex_Templates not checked out: see CONTRIBUTING.md, Documents (LaTeX))
endif
include Latex_Templates/core/build/docbuild.mk

# Settings (Latex_Templates/core/build/README.md), paths relative to this Makefile; commented lines show defaults:
DOCBUILD_SRC := software/Source_Documentation
DOCBUILD_OUT := software/PDF_Documentation
DOCBUILD_BASELINE := file
DOCBUILD_RELEASE_TAGS := false
# DOCBUILD_TAG_PREFIX :=
# DOCBUILD_DIFF := true
# DOCBUILD_TEXINPUTS :=
# PYTHON := python3

# The car-interface figure is the same TikZ code inline in both TDDs, so docbuild highlights its edits;
# build and release stop if the two copies differ.
FIGURE_MARKS := /^% BEGIN shared-figure car-interface/,/^% END shared-figure car-interface/p
.PHONY: check-figures
check-figures:
	@sed -n '$(FIGURE_MARKS)' $(DOCBUILD_SRC)/car/TDD_F1tenth.tex > .figure_car.tmp
	@sed -n '$(FIGURE_MARKS)' $(DOCBUILD_SRC)/sim/TDD_Gym.tex > .figure_sim.tmp
	@test -s .figure_car.tmp && cmp -s .figure_car.tmp .figure_sim.tmp \
	  || { rm -f .figure_car.tmp .figure_sim.tmp; \
	       echo "car-interface figure: the copies in TDD_F1tenth and TDD_Gym differ or are missing"; exit 1; }
	@rm -f .figure_car.tmp .figure_sim.tmp
build release: check-figures

# Groups of this repo's docs, e.g. make general:
# general:
# 	@$(MAKE) --no-print-directory build TDD_General RASD_General
