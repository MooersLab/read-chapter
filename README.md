![Version](https://img.shields.io/static/v1?label=rename-chapter&message=0.1&color=brightcolor)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Emacs](https://img.shields.io/badge/Emacs-27.1+-purple.svg)](https://www.gnu.org/software/emacs/)


# rename-chapter

> Replace LaTeX and Org-mode include filenames with chapter titles and rename the files on disk — all in one keystroke in Emacs, of course, the ultimate text editor where magic happens.

## Table of Contents

- [Problem addressed and its solution](#problem-addressed-and-its-solution)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Customization](#customization)
- [Running the Tests](#running-the-tests)
- [Code Coverage](#code-coverage)
- [Project Layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## Problem addressed and its solution

When you split a book or thesis into one file per chapter, the filenames in your `\include{}`, `\input{}`, or `#+INCLUDE:` statements quickly drift out of sync with the actual chapter titles.  **rename-chapter** fixes that: place your cursor on the include line, call `M-x rename-chapter`, and the package will

1. Open the referenced `.tex` or `.org` file,
2. Extract the `\chapter{}` title (or the first Org heading, or `#+TITLE:`),
3. Strip whitespace from the title,
4. Rename the file on disk, and
5. Update the include statement in your buffer.

## Features

- **LaTeX support** — parses both `\include{path}` and `\input{path}`.
- **Org-mode support** — parses `#+INCLUDE: "path"`.
- **Subdirectory-aware** — paths like `./Contents/ch03_methods` are handled correctly; the directory prefix is preserved.
- **Multiple title sources** — searches `\chapter{}` first, then top-level Org headings (`* …`), then `#+TITLE:`.
- **Customizable separator** — strip whitespace entirely (`MaterialsandMethods`), replace with underscores (`Materials_and_Methods`), or hyphens (`Materials-and-Methods`).
- **Safe** — refuses to overwrite an existing file with the target name.

## Requirements

- **Emacs 27.1** or later (for `string-empty-p`, `cl-lib` built-in, and `lexical-binding` defaults).

No external dependencies are needed.

## Installation

### Option A — Clone and load manually

```bash
git clone https://github.com/MooersLab/rename-chapter.git ~/path/to/rename-chapter
```

Add to your init file (`~/.emacs.d/init.el` or `~/.emacs`):

```elisp
(add-to-list 'load-path "~/path/to/rename-chapter")
(require 'rename-chapter)
(define-key LaTeX-mode-map (kbd "C-c C-r") #'rename-chapter)
(define-key org-mode-map   (kbd "C-c C-r") #'rename-chapter)
```

### Option B — use-package with a local checkout

```elisp
(use-package rename-chapter
  :load-path "~/path/to/rename-chapter"
  :bind (:map LaTeX-mode-map
         ("C-c C-r" . rename-chapter)
         :map org-mode-map
         ("C-c C-r" . rename-chapter)))
```

### Option C — straight.el

```elisp
(use-package rename-chapter
  :straight (:host github :repo "MooersLab/rename-chapter")
  :bind (:map LaTeX-mode-map
         ("C-c C-r" . rename-chapter)
         :map org-mode-map
         ("C-c C-r" . rename-chapter)))
```

### Option D — Manual single-file install

Copy `rename-chapter.el` somewhere on your `load-path` and add `(require 'rename-chapter)` to your init file.

## Usage

### Basic workflow

1. Open your main `.tex` or `.org` file — the one with the include statements.
2. Place your cursor anywhere on the line that contains the include:

   ```tex
   \include{./Contents/ch03_methods}
   ```

   or

   ```org
   #+INCLUDE: "./Contents/chapter1.org"
   ```

3. Run `M-x rename-chapter` (or press your keybinding, e.g. `C-c C-r`).
4. The package reads `ch03_methods.tex`, finds `\chapter{Materials and Methods}`, and then:
   - renames `./Contents/ch03_methods.tex` → `./Contents/MaterialsandMethods.tex`
   - updates the line to `\include{./Contents/MaterialsandMethods}`

### Before and after

| Style | Before | After |
|---|---|---|
| LaTeX | `\include{./Contents/ch03_methods}` | `\include{./Contents/MaterialsandMethods}` |
| LaTeX | `\input{intro}` | `\input{IntroductiontoCrystallography}` |
| Org | `#+INCLUDE: "./Contents/chapter1.org"` | `#+INCLUDE: "./Contents/IntroductiontoCrystallography.org"` |

## Customization

Two user options control how whitespace in the chapter title is replaced.  You can change them interactively with `M-x customize-group RET rename-chapter` or set them in your init file.

| Variable | Default | Effect |
|---|---|---|
| `rename-chapter-strip-regexp` | `"\\s-+"` | Regexp matching characters to remove |
| `rename-chapter-strip-replacement` | `""` | Replacement string |

### Examples

```elisp
;; Default: strip all whitespace
;; "Materials and Methods" → "MaterialsandMethods"

;; Underscores instead of removal:
(setq rename-chapter-strip-replacement "_")
;; "Materials and Methods" → "Materials_and_Methods"

;; Hyphens:
(setq rename-chapter-strip-replacement "-")
;; "Materials and Methods" → "Materials-and-Methods"
```

## Running the Tests

The test suite uses Emacs' built-in [ERT](https://www.gnu.org/software/emacs/manual/html_node/ert/) framework.  Every test creates its own temporary directory with fixture files, so no manual setup is needed and nothing on your real filesystem is touched.

### From the command line (recommended for CI)

```bash
# Run the full test suite
make test

# Byte-compile with warnings as errors (lint)
make lint

# Run tests with code coverage (requires undercover.el)
make coverage

# Both lint + test
make all
```

You can point to a specific Emacs binary:

```bash
make test EMACS=/usr/local/bin/emacs-29
```

### From inside Emacs

```
M-x ert RET t RET
```

This runs every test whose name matches the pattern `t` (i.e., all tests).  To run a single test:

```
M-x ert RET rc-test-integration-latex-include RET
```

### What the tests cover

| Category | Count | Description |
|---|---|---|
| Title extraction | 5 | `\chapter{}`, Org heading, `#+TITLE:`, missing title, priority ordering |
| File resolution | 5 | Bare names, extensions, subdirectories, missing files |
| Line parsing | 5 | `\include`, `\input`, `#+INCLUDE:`, no-subdir variant, error on plain text |
| Path building | 5 | LaTeX ± extension, Org ± extension, no subdirectory |
| Title cleaning | 4 | Default strip, underscore, hyphen, no-op |
| Integration | 5 | Full round-trip for LaTeX include, input, Org include, Org #+TITLE, custom replacement |
| Error paths | 4 | No include on line, file not found, no title in file, target already exists |
| **Total** | **33** | |

## Code Coverage

Coverage is provided by [undercover.el](https://github.com/undercover-el/undercover.el), which instruments `rename-chapter.el` at load time, runs the ERT suite, and writes an LCOV report.

### Prerequisites

Install undercover once from MELPA:

```
M-x package-install RET undercover RET
```

You also need [lcov](https://github.com/linux-test-project/lcov) if you want an HTML report (optional):

```bash
# macOS
brew install lcov

# Debian / Ubuntu
sudo apt install lcov
```

### Generate an LCOV report

```bash
make coverage
```

This produces `coverage/lcov.info`.  If undercover is installed somewhere other than the default `package-user-dir`, pass the path:

```bash
make coverage UNDERCOVER_LOAD_PATH=~/.emacs.d/elpa/undercover-0.8.1
```

### Generate an HTML report

```bash
make coverage-html
open coverage/html/index.html     # macOS
xdg-open coverage/html/index.html # Linux
```

The HTML report shows per-file and per-line hit counts, making it easy to spot untested branches.

### CI integration (Codecov / Coveralls)

On GitHub Actions (or any CI that undercover recognizes), edit `test/coverage-helper.el` and set `:send-report t`.  undercover will then post results directly to Coveralls or Codecov.  See the [undercover.el README](https://github.com/undercover-el/undercover.el#readme) for provider-specific setup.

## Project Layout

```
rename-chapter/
├── rename-chapter.el          # The package (single file)
├── test/
│   ├── rename-chapter-test.el # ERT test suite (33 tests)
│   └── coverage-helper.el     # undercover.el bootstrap for coverage
├── Makefile                   # compile, test, lint, coverage targets
├── .gitignore                 # Ignores *.elc and coverage/
├── README.md                  # This file
└── LICENSE                    # GPL-3.0-or-later
```

## Status

- Alpha
- Not in MELPA yet.
- Code works.
- All 33 tests pass.

## Contributing

Contributions are welcome.  Please open an issue to discuss significant changes before submitting a pull request.

1. Fork the repository.
2. Create a feature branch: `git checkout -b my-feature`.
3. Make sure `make all` passes before committing.
4. Submit a pull request.

## License

This project is licensed under the GNU General Public License v3.0.  See [LICENSE](LICENSE) for details.
