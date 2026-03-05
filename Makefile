# Makefile for rename-chapter — an Emacs Lisp package
#
# Targets
# -------
#   make            — byte-compile the package (default)
#   make test       — run the full ERT test suite in batch mode
#   make lint       — byte-compile with warnings treated as errors
#   make coverage   — run tests with undercover.el and produce coverage/lcov.info
#   make clean      — remove generated .elc files and coverage reports
#   make all        — lint + test
#
# Variables
# ---------
#   EMACS   — path to the Emacs binary (default: emacs)

EMACS   ?= emacs
BATCH    = $(EMACS) --batch -Q

# Source and test files
SRC      = rename-chapter.el
TEST     = test/rename-chapter-test.el
COVHELP  = test/coverage-helper.el
ELC      = $(SRC:.el=.elc)
COVDIR   = coverage

# ——————————————————————————————————————————————
# Default target
# ——————————————————————————————————————————————
.PHONY: compile
compile: $(ELC)

%.elc: %.el
	$(BATCH) -L . -f batch-byte-compile $<

# ——————————————————————————————————————————————
# Run the ERT test suite
# ——————————————————————————————————————————————
.PHONY: test
test:
	$(BATCH) -L . -l $(TEST) -f ert-run-tests-batch-and-exit

# ——————————————————————————————————————————————
# Byte-compile with warnings as errors (CI lint)
# ——————————————————————————————————————————————
.PHONY: lint
lint:
	$(BATCH) -L . \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $(SRC)

# ——————————————————————————————————————————————
# Test with code coverage via undercover.el
#
# Prerequisites (one-time):
#   1. Install undercover from MELPA:
#        M-x package-install RET undercover RET
#      or place undercover.el on your load-path.
#
#   2. Pass UNDERCOVER_LOAD_PATH to the directory that
#      contains undercover.el if it is not in a standard
#      location:
#        make coverage UNDERCOVER_LOAD_PATH=~/.emacs.d/elpa/undercover-0.8.1
#
# Output:  coverage/lcov.info
# ——————————————————————————————————————————————
UNDERCOVER_LOAD_PATH ?=

.PHONY: coverage
coverage:
	@mkdir -p $(COVDIR)
	$(BATCH) -L . \
	  $(if $(UNDERCOVER_LOAD_PATH),-L $(UNDERCOVER_LOAD_PATH)) \
	  -l $(COVHELP) \
	  -l $(TEST) \
	  -f ert-run-tests-batch-and-exit
	@echo ""
	@echo "Coverage report written to $(COVDIR)/lcov.info"
	@echo ""
	@echo "To view as HTML (requires lcov):"
	@echo "  genhtml $(COVDIR)/lcov.info -o $(COVDIR)/html"
	@echo "  open $(COVDIR)/html/index.html"

# ——————————————————————————————————————————————
# Generate an HTML coverage report from lcov.info
# Requires: lcov  (apt install lcov / brew install lcov)
# ——————————————————————————————————————————————
.PHONY: coverage-html
coverage-html: coverage
	genhtml $(COVDIR)/lcov.info \
	  --output-directory $(COVDIR)/html \
	  --title "rename-chapter coverage" \
	  --legend
	@echo ""
	@echo "Open $(COVDIR)/html/index.html in a browser."

# ——————————————————————————————————————————————
# Run everything
# ——————————————————————————————————————————————
.PHONY: all
all: lint test

# ——————————————————————————————————————————————
# Housekeeping
# ——————————————————————————————————————————————
.PHONY: clean
clean:
	rm -f *.elc
	rm -rf $(COVDIR)
