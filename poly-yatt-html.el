;;; poly-yatt-html.el --- poly-yatt-html-mode polymode -*- lexical-binding: t -*-
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

(require 'polymode)

(require 'mhtml-mode)
;; (defalias 'html-mode 'mhtml-mode);; Not worked

(eval-when-compile
  (require 'cl-lib))

(require 'poly-yatt-config)

(require 'newcomment)

(defvar poly-yatt-html-mode-before-hook nil
  "Hook which runs before (poly-yatt-load-config)")

(defvar poly-yatt-html-mode--debug nil
  "Emit debug messages")

(defvar poly-yatt-html-mode-hook nil
  "Hook for general customization of poly-yatt-html-mode")

(defvar poly-yatt-html-linter-alist
  '((yatt-js . yatt-js-lint-mode)
    (yatt-lite . yatt-lint-any-mode))
  "Alist of yatt implementations vs corresponding linter mode")

(defcustom poly-yatt-comment-style 'extra-line
  "Style to be used for ‘comment-region’."
  :type `(choice
          ,@(mapcar #'(lambda (i)
                        (let* ((kw (nth 0 i))
                               (doc (concat (symbol-name kw) " - " (nth 5 i))))
                        `(const :tag ,doc ,kw)))
                    comment-styles)))

(defvar-local poly-yatt--config nil)

(defvar poly-yatt-default-target-lang 'typescript)
(defvar-local poly-yatt--target-lang nil)

(defvar-local poly-yatt--comment-regexp nil)

(defun poly-yatt--compose-comment-regexp (&optional config)
  (let ((nspat
         (poly-yatt--vector-to-regexp
          (poly-yatt-namespace config)))
        (old-comment-close
         (cdr (assoc 'old-comment-close (or config poly-yatt--config)))))
    (string-join
     (list
      (format "<!\\(--#%s\\b\\)" nspat)
      (format "\\(%s-->\\)" (if old-comment-close "" "#")))
     "\\|")))

(defun poly-yatt-namespace (&optional config)
  (or (cdr (assoc 'namespace (or config poly-yatt--config)))
      ["yatt"]))

(defun poly-yatt--vector-to-regexp (vec)
  (if (>= (length vec) 2)
      (concat
       "\\(?:"
       (string-join vec "\\|")
       "\\)")
    (elt vec 0)))

(defvar-local poly-yatt--multipart-regexp
  nil)

(defun poly-yatt--compose-multipart-regexp (&optional config)
  (let ((nspat
         (poly-yatt--vector-to-regexp
          (poly-yatt-namespace config)))
        (old-comment-close
         (cdr (assoc 'old-comment-close (or config poly-yatt--config)))))
    (string-join
     (list
      (format "<!\\(--#%s\\b\\)" nspat)
      (format "^<!%s:\\([[:alnum:]]+\\)\\(\\(?::[[:alnum:]]+\\)+\\)?\\b" nspat)
      (format "\\(%s-->\\)" (if old-comment-close "" "#")))
     "\\|")))

(defun poly-yatt-multipart-head (ahead)
  (or (equal (point) 0)
      (poly-yatt-multipart-boundary ahead)))

(defun poly-yatt-multipart-boundary (ahead)
  (let ((match (poly-yatt-multipart-match ahead)))
    (when match
      (cl-destructuring-bind
          (tag-begin decl-end
                     _decl-open-begin _decl-open-end
                     _opt-begin _opt-end)
          match
        (cons tag-begin decl-end)))))

(defun poly-yatt-multipart-mode-matcher ()
  (let ((match (poly-yatt-multipart-match 1)))
    (cond
     (match
      (let ((res (poly-yatt-multipart--classify-part-kind
                  (poly-yatt-multipart--extract-match-kind match))))
        (if poly-yatt-html-mode--debug
            (message "found mode %s at %d" res (point)))
        (if (eq res 'host)
            "mhtml";; XXX: customize??
          res)))
     (t
      (if poly-yatt-html-mode--debug
          (message "no mode found at %d" (point)))
      nil))))

(defun poly-yatt-multipart--extract-match-kind (match)
  (cl-destructuring-bind
      (_tag-begin _decl-end
                  decl-open-begin decl-open-end
                  _opt-begin _opt-end)
      match
    (buffer-substring-no-properties
     decl-open-begin decl-open-end)))

(defun poly-yatt-multipart--classify-part-kind (kind)
  (cond
   ((member kind '("widget" "args" "page"))
    'host)
   ((member kind '("action" "entity"))
    poly-yatt--target-lang)))

(defun poly-yatt-multipart-match (ahead)
  (if poly-yatt-html-mode--debug
      (message "called multipart-match at %d" (point)))
  (cl-block nil
    (while (re-search-forward poly-yatt--multipart-regexp nil t ahead)
      (cl-destructuring-bind
          (all-begin all-end
                     comment-open-begin _comment-open-end
                     &optional
                     decl-open-begin decl-open-end
                     opt-begin  opt-end
                     comment-close-begin _comment-close-end)
          (match-data)
        (cond
         (comment-open-begin
          (when (> ahead 0)
            (poly-yatt-comment-match ahead 1)))

         (comment-close-begin
          (when (< ahead 0)
            (poly-yatt-comment-match ahead 1)))

         (decl-open-begin
          (let* (;; < の位置
                 (tag-begin (marker-position all-begin))
                 ;; 閉じ > を探す
                 (tag-close
                  (with-syntax-table sgml-tag-syntax-table
                    ;; 一旦 < に戻り、
                    (goto-char tag-begin)
                    ;; そこから > の後まで進む
                    (condition-case nil
                        (goto-char (scan-sexps (point) 1))
                      (error
                       ;; '' や "" の片割れを入力した瞬間は scan-exps が
                       ;; エラーになる。その場合は単に > まで移動
                       (search-forward ">")))))

                 ;; 次の改行も decl に含める
                 (decl-end (if (eq (char-after tag-close) ?\n)
                               (1+ tag-close) tag-close)))
            (cl-return (list tag-begin decl-end
                             decl-open-begin decl-open-end
                             opt-begin opt-end))))

         (t
          (error "Really?")))))))

(defun poly-yatt-comment-match (ahead depth)
  (cl-block nil
    (while (re-search-forward poly-yatt--comment-regexp nil t ahead)
      (cl-destructuring-bind
          (_all-begin _all-end
                     comment-open-begin _comment-open-end
                     &optional comment-close-begin _comment-close-end)
          (match-data)
        (let ((new-depth (if (> ahead 0)
                             (if comment-open-begin (1+ depth) (1- depth))
                           (if comment-close-begin (1+ depth) (1- depth)))))
          (if (eq new-depth 0)
              (cl-return (point))))))))

(defface poly-yatt-declaration-face
  '((t (:background "#d2d4f1" :extend t)))
  "Face used for yatt declaration block (<!yatt:...>)")

(defface poly-yatt-action-face
  '((t (:background "#f4f2f5" :extend t)))
  "Face used for yatt action part (<!yatt:...>)")

;; XXX: take namespace configuration from... yatt.config.json?
;; multipart (+ comment) handling

(define-hostmode poly-yatt-html-hostmode
  :mode 'mhtml-mode
  :indent-offset 'sgml-basic-offset
  :protect-font-lock t
  :protect-syntax t)

;; (define-auto-innermode poly-yatt-multipart-innermode
;;   :adjust-face 0
;;   :head-adjust-face 'poly-yatt-declaration-face
;;   :head-matcher 'poly-yatt-multipart-head
;;   :tail-matcher 'poly-yatt-multipart-boundary
;;   :mode-matcher 'poly-yatt-multipart-mode-matcher
;;   :head-mode 'host
;;   :tail-mode 'host)

(defclass pm-inner-poly-yatt-auto-chunkmode (pm-inner-auto-chunkmode) ())

(eval
 (polymode--define-chunkmode
  'pm-inner-poly-yatt-auto-chunkmode
  'poly-yatt-multipart-innermode
  nil nil;; doc parent
  '(
    :adjust-face 0
    :head-adjust-face 'poly-yatt-declaration-face
    :head-matcher 'poly-yatt-multipart-head
    :tail-matcher 'poly-yatt-multipart-boundary
    :mode-matcher 'poly-yatt-multipart-mode-matcher
    :head-mode 'host
    :tail-mode 'host)
  ))

(cl-defmethod pm-get-adjust-face ((chunkmode pm-inner-poly-yatt-auto-chunkmode) type)
  (if (and (eq type 'body)
           (not
            (save-excursion
             (let ((match (poly-yatt-multipart-match -1)))
               (eq 'host
                   (poly-yatt-multipart--classify-part-kind
                    (poly-yatt-multipart--extract-match-kind match)))))))
      'poly-yatt-action-face
    (cl-call-next-method chunkmode type)))

(cl-defmethod pm-indent-line ((_chunkmode pm-inner-poly-yatt-auto-chunkmode) span)
  (mhtml-indent-line))

;;;###autoload (autoload 'poly-yatt-html-mode "poly-yatt-html" nil t)
(define-polymode poly-yatt-html-mode
  :hostmode 'poly-yatt-html-hostmode
  :innermodes '(poly-yatt-multipart-innermode)
  ;; XXX: yattconfig.json を読む…それとも package.json?
  ;; XXX: namespace を設定する
  ;; XXX: ターゲット言語を設定する
  ;; XXX: 保存時 lint を設定する…
  ;; XXX: いっそ language server を？

  ;; run hook before loading yatt config
  (run-hooks 'poly-yatt-html-mode-before-hook)

  (message "loading yatt config")
  (setq poly-yatt--config (poly-yatt-load-config))

  (let ((ns (aref (poly-yatt-namespace) 0)))
    (setq-local comment-start    (concat "<!--#" ns ""))
    (setq-local comment-continue " # ")
    (setq-local comment-end      " #-->")
    (setq-local comment-style poly-yatt-comment-style))

  (setq poly-yatt--comment-regexp
        (poly-yatt--compose-comment-regexp poly-yatt--config)

        poly-yatt--multipart-regexp
        (poly-yatt--compose-multipart-regexp poly-yatt--config)

        poly-yatt--target-lang
        (or (cdr (assoc 'target poly-yatt--config))
            poly-yatt-default-target-lang))

  (let* ((impl (cdr (assoc 'yatt-impl poly-yatt--config)))
         (linter (cdr (assoc impl poly-yatt-html-linter-alist))))
    (when linter
      (cond ((symbolp linter)
             (message "Enabling linter %s" linter)
             (funcall linter t)
             )
            (t
             (error "Unsupported form linter %s" linter)))))
  )

(provide 'poly-yatt-html)
;;; poly-yatt-html.el ends here
