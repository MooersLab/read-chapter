;;; rename-chapter.el --- Replace include filenames with chapter titles -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Blaine Mooers

;; Author: Blaine Mooers <bmooers1@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, book files, tex, org
;; URL: https://github.com/MooersLab/rename-chapter

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; rename-chapter provides an interactive command that replaces the
;; filename inside a LaTeX or Org-mode include statement with the
;; whitespace-free chapter title extracted from the referenced file,
;; and then renames that file on disk to match.
;;
;; Supported include styles:
;;
;;   LaTeX:  \include{./Contents/ch03_methods}
;;           \input{./Contents/ch03_methods}
;;   Org:    #+INCLUDE: "./Contents/chapter1.org"
;;
;; The chapter title is taken from the first match among:
;;
;;   1. \chapter{...}         (in .tex or .org files)
;;   2. A top-level heading   (* Heading)
;;   3. #+TITLE: ...
;;
;; Whitespace is stripped from the title before it is used as the new
;; filename.  The subdirectory prefix and file extension are preserved.
;;
;; Installation:
;;
;;   ;; With use-package and a local checkout:
;;   (use-package rename-chapter
;;     :load-path "~/path/to/rename-chapter"
;;     :bind (:map LaTeX-mode-map
;;            ("C-c r" . rename-chapter)
;;            :map org-mode-map
;;            ("C-c r" . rename-chapter)))
;;
;;   ;; Or simply:
;;   (require 'rename-chapter)
;;   (global-set-key (kbd "C-c r") #'rename-chapter)

;;; Code:

(require 'cl-lib)

;; ------------------------------------------------------------------
;; Customization
;; ------------------------------------------------------------------

(defgroup rename-chapter nil
  "Replace include filenames with chapter titles and rename files."
  :group 'convenience
  :prefix "rename-chapter-")

(defcustom rename-chapter-strip-regexp "\\s-+"
  "Regexp matching characters to strip from the chapter title.
The default removes all whitespace.  Change to, for example,
\"[ ]\" to remove only spaces while keeping tabs and newlines."
  :type 'regexp
  :group 'rename-chapter)

(defcustom rename-chapter-strip-replacement ""
  "String that replaces every match of `rename-chapter-strip-regexp'.
Set to \"_\" or \"-\" if you prefer underscores or hyphens instead
of simple removal."
  :type 'string
  :group 'rename-chapter)

;; ------------------------------------------------------------------
;; Internal helpers
;; ------------------------------------------------------------------

(defun rename-chapter--title-from-file (file-path)
  "Return the chapter title found in FILE-PATH, or nil.
Searches for \\chapter{}, then a top-level Org heading, then #+TITLE:."
  (with-temp-buffer
    (insert-file-contents file-path)
    (goto-char (point-min))
    (cond
     ;; LaTeX \chapter{...}
     ((re-search-forward "\\\\chapter{\\([^}]+\\)}" nil t)
      (match-string 1))
     ;; Org first-level heading
     ((re-search-forward "^\\* \\(.+\\)$" nil t)
      (match-string 1))
     ;; Org #+TITLE:
     ((progn (goto-char (point-min))
             (re-search-forward
              "^#\\+[Tt][Ii][Tt][Ll][Ee]: *\\(.+\\)$" nil t))
      (match-string 1)))))

(defun rename-chapter--resolve-file (filepath base-dir)
  "Return the first existing path for FILEPATH under BASE-DIR.
Tries the path as given, then with .tex and .org appended.
FILEPATH may contain subdirectories."
  (let ((expanded (expand-file-name filepath base-dir)))
    (cl-find-if #'file-exists-p
                (list expanded
                      (concat expanded ".tex")
                      (concat expanded ".org")))))

(defun rename-chapter--parse-include ()
  "Parse the include statement on the current line.
Return a plist (:beg :end :path :style) or signal an error.

:beg   – buffer position of the start of the replaceable path
:end   – buffer position of the end   of the replaceable path
:path  – the raw path string (may include subdirectories)
:style – either `latex' or `org'"
  (save-excursion
    (let ((line-beg (line-beginning-position))
          (line-end (line-end-position)))
      (beginning-of-line)
      (cond
       ;; Org-mode #+INCLUDE: "path"
       ((re-search-forward
         "^#\\+INCLUDE: *\"\\([^\"]+\\)\""
         line-end t)
        (list :beg   (match-beginning 1)
              :end   (match-end 1)
              :path  (match-string 1)
              :style 'org))
       ;; LaTeX \include{path} or \input{path}
       (t
        (goto-char line-beg)
        (if (re-search-forward
             "\\\\\\(?:include\\|input\\){\\([^}]+\\)}"
             line-end t)
            (list :beg   (match-beginning 1)
                  :end   (match-end 1)
                  :path  (match-string 1)
                  :style 'latex)
          (user-error
           "No \\include{}, \\input{}, or #+INCLUDE found on this line")))))))

(defun rename-chapter--build-new-path (old-path clean-title style)
  "Return the new path string to insert into the buffer.
OLD-PATH is the original reference (e.g. \"./Contents/ch03_methods\").
CLEAN-TITLE is the whitespace-free chapter title.
STYLE is either `latex' or `org'.

For LaTeX the extension is omitted when the original omitted it.
For Org the extension is always preserved."
  (let* ((dir       (file-name-directory old-path))
         (old-ext   (file-name-extension old-path t))
         (has-ext   (not (string-empty-p old-ext)))
         (extension (pcase style
                      ('org   (if has-ext old-ext ".org"))
                      ('latex (if has-ext old-ext ""))))
         (new-name  (concat clean-title extension)))
    (if dir
        (concat dir new-name)
      new-name)))

(defun rename-chapter--clean-title (raw-title)
  "Return RAW-TITLE with whitespace stripped per user customization."
  (replace-regexp-in-string
   rename-chapter-strip-regexp
   rename-chapter-strip-replacement
   raw-title))

;; ------------------------------------------------------------------
;; Public command
;; ------------------------------------------------------------------

;;;###autoload
(defun rename-chapter ()
  "Replace the include filename at point with the chapter title and rename the file.

Point must be on a line containing one of:
  \\include{path}   \\input{path}   #+INCLUDE: \"path\"

The function:
  1. Parses the include statement to extract the file path.
  2. Opens the referenced .tex or .org file.
  3. Extracts the \\chapter{} title (or Org heading / #+TITLE).
  4. Strips whitespace from the title (configurable via
     `rename-chapter-strip-regexp' and
     `rename-chapter-strip-replacement').
  5. Renames the file on disk, preserving the directory and extension.
  6. Updates the include statement in the current buffer."
  (interactive)
  (let* ((base-dir (or (and (buffer-file-name)
                            (file-name-directory (buffer-file-name)))
                       default-directory))
         ;; 1. Parse ----------------------------------------------------------
         (info      (rename-chapter--parse-include))
         (beg       (plist-get info :beg))
         (end       (plist-get info :end))
         (old-path  (plist-get info :path))
         (style     (plist-get info :style))
         ;; 2. Resolve --------------------------------------------------------
         (old-file  (rename-chapter--resolve-file old-path base-dir)))
    (unless old-file
      (user-error "Cannot find file for \"%s\" under %s" old-path base-dir))

    (let ((raw-title (rename-chapter--title-from-file old-file)))
      (unless raw-title
        (user-error "No \\chapter{} or top-level heading found in %s"
                    (file-name-nondirectory old-file)))

      (let* (;; 3. Clean -------------------------------------------------------
             (clean-title (rename-chapter--clean-title raw-title))
             ;; 4. New paths ----------------------------------------------------
             (new-include (rename-chapter--build-new-path
                           old-path clean-title style))
             (old-dir     (file-name-directory old-file))
             (old-ext     (file-name-extension old-file t))
             (new-file    (expand-file-name
                           (concat clean-title old-ext)
                           (or old-dir base-dir))))

        ;; 5. Safety -----------------------------------------------------------
        (when (and (file-exists-p new-file)
                   (not (string= (file-truename old-file)
                                 (file-truename new-file))))
          (user-error "Target file already exists: %s" new-file))

        ;; 6. Rename on disk ---------------------------------------------------
        (rename-file old-file new-file)

        ;; 7. Update the buffer ------------------------------------------------
        (delete-region beg end)
        (goto-char beg)
        (insert new-include)

        (message "rename-chapter: \"%s\" -> \"%s\"  |  %s -> %s"
                 old-path new-include
                 (file-name-nondirectory old-file)
                 (file-name-nondirectory new-file))))))

(provide 'rename-chapter)
;;; rename-chapter.el ends here