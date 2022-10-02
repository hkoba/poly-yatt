;;; poly-yatt-config.el  -*- lexical-binding: t -*-
;;
;; Author: Hiroaki Kobayashi
;; Maintainer: Hiroaki Kobayashi
;; Copyright (C) 2022 Hiroaki Kobayashi
;; Version: 0.1
;; Package-Requires: ((emacs "25") (polymode "0.2.2"))
;; URL: https://github.com/hkoba/yatt-js
;; Keywords: languages, multi-modes, html, templates, yatt
;;
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

(eval-when-compile
  (require 'cl-lib))
(require 'dash)

(require 'json)

(defvar poly-yatt-config-loader-list '(yatt-js))

;;;###autoload
(defun poly-yatt-load-config ()
  (or
   (cl-dolist (k poly-yatt-config-loader-list)
     (let* (cfg
            (key (if (symbolp k) (symbol-name k) k))
            (finder (intern-soft (concat "poly-yatt-config--find-" key)))
            (loader (intern-soft (concat "poly-yatt-config--load-" key))))
       (when (and finder (fboundp finder) loader (fboundp loader)
                  (setq cfg (funcall finder)))
         (cl-return (cons (cons 'yatt-impl (intern key))
                          (funcall loader cfg))))))
   ;;; XXX: Customize
   (list
    (cons 'yatt-impl 'yatt-js)
    (cons 'namespace ["yatt"])
    (cons 'old-comment-close nil))
   ))

(defun poly-yatt-config--find-yatt-pm ()
  (poly-yatt-config-find-file-upward ".htyattroot"))

(defun poly-yatt-config--load-yatt-pm (fn)
  (let* (raw
         result
         (converter "xhf2json.pl")
         (avail (-any? (lambda (p)
                         (let ((fn (concat p "/" converter)))
                           (file-exists-p fn)))
                       exec-path)))
    (setq raw (if avail
                  (with-temp-buffer
                    (call-process converter nil (current-buffer) nil fn)
                    (goto-char (point-min))
                    (json-read))
                (poly-yatt-parse-xhf-file fn)))
    (list (cons 'target "perl")
          (or (assoc 'namespace raw)
              (cons 'namespace ["yatt"]))
          (cons 'old-comment-close t)
          (cons 'raw raw))
    ))

(defun poly-yatt-parse-xhf-file (fn)
  (error "Not yet implemented"))

(defun poly-yatt-config--find-yatt-lite ()
  (poly-yatt-config-find-file-upward "app.psgi"))
(defun poly-yatt-config--load-yatt-lite (cfg)
  (list (cons 'target "perl")
        (cons 'namespace ["yatt"])
        (cons 'old-comment-close t)))

(defun poly-yatt-config--find-yatt-js ()
  (message "Searching yattconfig.json")
  (poly-yatt-config-find-file-upward "yattconfig.json"))
(defun poly-yatt-config--load-yatt-js (cfg)
  (json-read-file cfg))

;;; Ported from github.com/hkoba/yatt_lite/elisp/yatt-lint-any-mode.el

(defun poly-yatt-config-find-file-upward (file &optional startdir)
  "Search FILE from STARTDIR and its parent, upto /."
  (-if-let (full (or startdir (-if-let (fn (buffer-file-name (current-buffer)))
                                  (file-name-directory fn))))
      (let ((prefix (file-remote-p full))
	    (dir    (poly-yatt-config-tramp-localname full))
	    fn)
        (while (and
	        dir
	        (not (equal dir "/"))
	        (not (file-exists-p (setq fn (concat prefix dir file)))))
          (setq dir (file-name-directory (directory-file-name dir))))
        (if (file-exists-p fn)
	    fn))))

(defun poly-yatt-config-tramp-localname (fn-or-buf)
  ;;; XXX: How about accepting dissected-vec as argument?
  (let ((fn (cond ((stringp fn-or-buf)
		   fn-or-buf)
		  ((bufferp fn-or-buf)
		   (buffer-file-name fn-or-buf))
		  (t
		   (error "Invalid argument %s" fn-or-buf)))))
    (if (poly-yatt-config-is-tramp fn)
	(let ((vec (tramp-dissect-file-name fn)))
	  (tramp-file-name-localname vec))
      fn)))

(defun poly-yatt-config-any-shell-command (cmd &rest args)
  (let ((tmpbuf (generate-new-buffer " *poly-yatt-config-temp*"))
	rc err)
    (save-window-excursion
      (unwind-protect
	  (setq rc (poly-yatt-config-tramp-command-in
		    (current-buffer)
		    cmd args tmpbuf))
	(setq err (with-current-buffer tmpbuf
		    ;; To remove last \n
		    (goto-char (point-max))
		    (skip-chars-backward "\n")
		    (delete-region (point) (point-max))
		    (buffer-string)))
	;; (message "error=(((%s)))" err)
	(kill-buffer tmpbuf)))
    `((rc . ,rc) (err . ,err))))

(defun poly-yatt-config-tramp-command-in (curbuf cmd args &optional outbuf errorbuf)
  (let ((command (apply #'concat (poly-yatt-config-tramp-localname cmd)
			args)))
    (if (poly-yatt-config-is-tramp (buffer-file-name curbuf))
	(tramp-handle-shell-command
	 command outbuf errorbuf)
      (shell-command command outbuf errorbuf))))

(defun poly-yatt-config-is-tramp (fn)
  (and (fboundp 'tramp-tramp-file-p)
       (tramp-tramp-file-p fn)))


(provide 'poly-yatt-config)
;;; poly-yatt-config.el ends here
