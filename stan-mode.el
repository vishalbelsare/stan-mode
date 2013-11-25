;;; stan-mode.el --- Major mode for editing STAN files

;; Copyright (C) 2012, 2013  Jeffrey Arnold, Daniel Lee

;; Author: Jeffrey Arnold <jeffrey.arnold@gmail.com>,
;;   Daniel Lee <bearlee@alum.mit.edu>
;; Maintainer: Jeffrey Arnold <jeffrey.arnold@gmail.com>,
;;   Daniel Lee <bearlee@alum.mit.edu>
;; URL: http://github.com/stan-dev/stan-mode
;; Keywords: languanges
;; Version: 1.2.0
;; Created: 2012-08-18

;; This file is not part of GNU Emacs.

;;; License:
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <http://www.gnu.org/licenses/>

;;; Commentary:
;;
;; This is a major mode for the Stan modeling language for Bayesian
;; statistics. See http://mc-stan.org/.
;;
;; To load this library:
;;
;;   (require 'stan-mode)
;;
;; This mode currently supports syntax-highlighting, indentation (via
;; the cc-mode indentation engine), imenu, and compiler-mode regular
;; expressions.
;;
;; Yasnippet and flymake support for stan are provided in separate
;; libraries included with stan-mode.
;;
;; Yasnippet support is provided in stan-snippets.
;;
;;   (require 'stan-snippets)
;;
;; Flymake support is provided in flymake-stan.
;;
;;   (require 'flymake-stan)

;;; Code:
(require 'font-lock)
(require 'cc-mode)
(require 'compile)

(require 'stan-keywords-lists)

;;
;; Customizable Variables
;;
(defgroup stan-mode nil
  "A mode for Stan"
  :prefix "stan-"
  :group 'languages)

(defconst stan-mode-version "1.2.0"
  "stan-mode version number")

(defconst stan-language-version "2.0.1"
  "Stan language version supported")

(defcustom stan-mode-hook nil
  "Hook run when entering stan-mode"
  :type 'hook
  :group 'stan-mode)

(defcustom stan-comment-start "//"
  "Stan comment style to use"
  :type 'string
  :group 'stan-mode)

(defcustom stan-comment-end ""
  "Stan comment style to use"
  :type 'string
  :group 'stan-mode)

(defcustom stan-stanc-path
  "stanc"
  "Path to stanc executable"
  :type 'string
  :group 'stan-mode)

(defvar stan-mode-abbrev-table nil
  "Abbrev table used in stan-mode buffers.")

(define-abbrev-table 'stan-mode-abbrev-table ())

;; Syntax Table
(setq stan-mode-syntax-table (make-syntax-table c++-mode-syntax-table))
(modify-syntax-entry ?#  "< b"  stan-mode-syntax-table)
(modify-syntax-entry ?\n "> b"  stan-mode-syntax-table)
(modify-syntax-entry ?'  "." stan-mode-syntax-table)
;; _ should be part of symbol not word.
;; see
;; http://www.gnu.org/software/emacs/manual/html_node/elisp/Syntax-Class-Table.html#Syntax-Class-Table

;; Font-Locks

;; <- and ~
(defvar stan-assign-regexp
  "\\(<-\\|~\\)"
  "Assigment operators")

(defvar stan-blocks-regexp
  (concat "^[[:space:]]*\\(model\\|data\\|transformed[ \t]+data\\|parameters"
          "\\|transformed[ \t]+parameters\\|generated[ \t]+quantities\\)[[:space:]]*{")
  "Stan blocks declaration regexp")

(defun stan-regexp-opt (string)
  (concat "\\_<\\(" (regexp-opt string) "\\)\\_>"))

(defvar stan-var-decl-regexp
  (concat (stan-regexp-opt stan-types-list)
          "\\(?:<.*?>\\)?\\(?:\\[.*?\\]\\)?[[:space:]]+\\([A-Za-z0-9_]+\\)")
    "Stan variable declaration regex")

(defvar stan-font-lock-keywords
  `((,stan-blocks-regexp 1 font-lock-keyword-face)
    (,stan-assign-regexp . font-lock-reference-face)
    ;; Stan types. Look for it to come after the start of a line or semicolon.
    ( ,(concat "\\(^\\|;\\)\\s-*" (regexp-opt stan-types-list 'words)) 2 font-lock-type-face)
    ;; Variable declaration
    (,stan-var-decl-regexp 2 font-lock-variable-name-face)
    ;; keywords
    (,(stan-regexp-opt stan-keywords-list) . font-lock-keyword-face)
    ;; T
    ("\\(T\\)\\[.*?\\]" 1 font-lock-keyword-face)
    ;; check that lower and upper appear after a < or ,
    (,(concat "\\(?:<\\|,\\)\\s-*" (stan-regexp-opt stan-bounds-list))
     1 font-lock-keyword-face)
    (,(stan-regexp-opt stan-functions-list) . font-lock-function-name-face)
    (,(stan-regexp-opt stan-distribution-list) . font-lock-function-name-face)
    ;; distribution names can only appear after a ~
    (,(concat "~\\s-*\\(" (regexp-opt stan-distribution-list) "\\)\\_>")
     1 font-lock-function-name-face)
    ;; (,(concat "~\\s-*" (stan-regexp stan-distribution-list))
    ;;  . font-lock-function-name-face)
    (,(stan-regexp-opt stan-reserved-list) . font-lock-warning-face)
    ))

;; Compilation Regexp

(defvar stan-compilation-error-regexp-alist
  '(("\\(.*?\\) LOCATION:[ \t]+file=\\([^;]+\\); +line=\\([0-9]+\\), +column=\\([0-9]+\\)" 1 2 3 4))
  "Regular expression matching error messages from the 'stanc' compiler.")

(setq compilation-error-regexp-alist
      (append stan-compilation-error-regexp-alist
              compilation-error-regexp-alist))

;; Misc

(defun stan-version ()
  "Message the current stan-mode version"
  (interactive)
  (message "stan-mode version %s" stan-mode-version))

;; Imenu tags
(defvar stan-imenu-generic-expression
  `(("Variable" ,stan-var-decl-regexp 2)
    ("Block" ,stan-blocks-regexp 1))
  "Stan mode imenu expression")

;; Keymap
(defvar stan-mode-map (make-sparse-keymap)
  "Keymap for Stan major mode")

;; Indenting
;; 2 spaces
(defvar stan-style
  '("gnu"
    ;; # comments have syntatic class cpp-macro
    (c-offsets-alist . ((cpp-macro . 0)))))

(c-add-style "stan" stan-style)

;;
;; Define Major Mode
;;
(define-derived-mode stan-mode c++-mode "Stan"
  "A major mode for editing Stan files."
  :syntax-table stan-mode-syntax-table
  :abbrev-table stan-mode-abbrev-table
  :group 'stan-mode

  ;; syntax highlighting
  (setq font-lock-defaults '((stan-font-lock-keywords)))

  ;; comments
  (setq mode-name "Stan")
  ;;(setq comment-start stan-comment-start)
  (set (make-local-variable 'comment-start) stan-comment-start)
  (set (make-local-variable 'comment-end) stan-comment-end)
  ;; no tabs
  (setq indent-tabs-mode nil)
  ;; imenu
  (setq imenu-generic-expression stan-imenu-generic-expression)
  ;; indentation style
  (c-set-style "stan")
  )

(provide 'stan-mode)

;;; On Load
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.stan\\'" . stan-mode))

;;; stan-mode.el ends here
