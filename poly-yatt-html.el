;;; poly-yatt-html.el --- poly-yatt-html-mode polymode -*- lexical-binding: t -*-
;;
;; Author: Hiroaki Kobayashi
;; Maintainer: Hiroaki Kobayashi
;; Copyright (C) 2022 Hiroaki Kobayashi
;; Version: 0.1
;; Package-Requires: ((emacs "25") (polymode "0.2.2"))
;; URL: https://github.com/hkoba/yatt-js
;; Keywords: languages, multi-modes, yatt
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

(defvar-local poly-yatt--target-lang nil)

(defvar-local poly-yatt--comment-regexp
  "<!\\(--#yatt\\b\\)\\|\\(#-->\\)")

(defvar-local poly-yatt--multipart-regexp
  "<!\\(--#yatt\\b\\)\\|^<!yatt:\\([[:alnum:]]+\\)\\(\\(?::[[:alnum:]]+\\)+\\)?\\b\\|\\(#-->\\)")
;; XXX: construct regexp from config

(defun poly-yatt-multipart-boundary (ahead)
  (let ((match (poly-yatt-multipart-match ahead)))
    (when match
      (cl-destructuring-bind
          (tag-begin decl-end
                     decl-open-begin decl-open-end
                     opt-begin opt-end)
          match
        (cons tag-begin decl-end)))))

(defun poly-yatt-multipart-mode ()
  (let ((match (poly-yatt-multipart-match 1)))
    (when match
      (cl-destructuring-bind
          (tag-begin decl-end
                     decl-open-begin decl-open-end
                     opt-begin opt-end)
          match
        (let ((kind (buffer-substring-no-properties
                     decl-open-begin decl-open-end)))
          (cond
           ((equal kind "widget")
            'host)
           ((or (equal kind "action") (equal kind "entity"))
            poly-yatt--target-lang)))))))

(defun poly-yatt-multipart-match (ahead)
  (cl-block nil
    (while (re-search-forward poly-yatt--multipart-regexp nil t ahead)
      (cl-destructuring-bind
          (all-begin all-end
                     comment-open-begin comment-open-end
                     &optional
                     decl-open-begin decl-open-end
                     opt-begin  opt-end
                     comment-close-begin comment-close-end)
          (match-data)
        (cond
         (comment-open-begin
          (if (< ahead 0) (error "突然の開きコメント！"))
          (poly-yatt-comment-match ahead 1))

         (comment-close-begin
          (if (> ahead 0) (error "突然の閉じコメント！"))
          (poly-yatt-comment-match ahead 1))

         (decl-open-begin
          (let* (;; < の位置
                 (tag-begin (marker-position all-begin))
                 ;; 閉じ > を探す
                 (tag-close (scan-lists (marker-position all-end) 1 1))
                 ;; 次の改行も decl に含める
                 (decl-end (if (eq (char-after tag-close) ?\n)
                               (1+ tag-close) tag-close)))
            (return (list tag-begin decl-end
                          decl-open-begin decl-open-end
                          opt-begin opt-end))))

         (t
          (error "really?")))))))

(defun poly-yatt-comment-match (ahead depth)
  (cl-block nil
    (while (re-search-forward poly-yatt--comment-regexp nil t ahead)
      (cl-destructuring-bind
          (all-begin all-end
                     comment-open-begin comment-open-end
                     &optional comment-close-begin comment-close-end)
          (match-data)
        (let ((new-depth (if (> ahead 0)
                             (if comment-open-begin (1+ depth) (1- depth))
                           (if comment-close-begin (1+ depth) (1- depth)))))
          (if (eq new-depth 0)
              (return (point))))))))

;; XXX: take namespace configuration from... yatt.config.json?
;; multipart (+ comment) handling

(define-auto-innermode poly-yatt-multipart-innermode
  :head-matcher 'poly-yatt-multipart-boundary
  :tail-matcher 'poly-yatt-multipart-boundary
  :mode-matcher 'poly-yatt-multipart-mode
  :head-mode 'host
  :tail-mode 'host)

(define-polymode poly-yatt-html-mode
  :hostmode 'poly-html-hostmode
  :innermodes '(poly-yatt-multipart-innermode))

(provide 'poly-yatt-html)
;;; poly-yatt-html.el ends here
