;;; yatt-js-lint-mode.el --- yatt-js-lint-mode -*- lexical-binding: t -*-
;; Author: Hiroaki Kobayashi
;; Maintainer: Hiroaki Kobayashi
;; Copyright (C) 2022 Hiroaki Kobayashi
;; Version: 0.1
;; Package-Requires: ((emacs "25"))
;; URL: https://github.com/hkoba/yatt-js
;; Keywords: languages, lint, templates, yatt

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This file is *NOT* part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:

(require 'poly-yatt-config)

(defvar yatt-lint-js-mode-map (make-sparse-keymap))
(define-key yatt-lint-js-mode-map [f5] 'yatt-js-lint-run)

;;;###autoload
(define-minor-mode yatt-js-lint-mode
  "Lint yatt-js files"
  :lighter "<F5 lint>"
  :keymap yatt-lint-js-mode-map
  :global nil
  (let ((hook 'after-save-hook) (fn 'yatt-js-lint-run))
    (if yatt-js-lint-mode
        (progn
          (make-variable-buffer-local hook)
          (add-hook hook fn nil nil))
      (remove-hook hook fn nil))
    ))

;;;###autoload
(defun yatt-js-lint-run ()
  (interactive)
  (when yatt-js-lint-mode
    (let* ((res (poly-yatt-config-any-shell-command
                 "yattjs-lint"
                 " "
                 (poly-yatt-config-tramp-localname (current-buffer))))
           (rc (cdr (assoc 'rc res)))
           (errmsg (cdr (assoc 'err res)))
           )
      (when (setq pos (yatt-js-lint-parse-error errmsg))
        (goto-line (car pos))
        (when (> (cdr pos) 1)
            (forward-char (1- (cdr pos)))))
      (message "%s"
               (cond ((> (length errmsg) 0)
		    errmsg)
		   ((not (eq rc 0))
		    "Unknown error")
		   (t
		    "lint OK"))))))

(defun yatt-js-lint-parse-error (errmsg)
  (save-match-data
    (when (string-match "at [^ ]* line \\([0-9]+\\) column \\([0-9]+\\)" errmsg)
      (cons (string-to-number (match-string 1 errmsg))
            (string-to-number (match-string 2 errmsg))))))

(provide 'yatt-js-lint-mode)
;;; yatt-js-lint-mode.el ends here
