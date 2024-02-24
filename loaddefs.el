;;; loaddefs.el --- automatically extracted autoloads
;;
;;; Code:


;;;### (autoloads nil "poly-yatt" "poly-yatt.el" (0 0 0 0))
;;; Generated autoloads from poly-yatt.el
 (autoload 'poly-yatt-mode "poly-yatt" nil t)

(register-definition-prefixes "poly-yatt" '("pm-inner-poly-yatt-auto-chunkmode" "poly-yatt-"))

;;;***

;;;### (autoloads nil "poly-yatt-config" "poly-yatt-config.el" (0
;;;;;;  0 0 0))
;;; Generated autoloads from poly-yatt-config.el

(autoload 'poly-yatt-load-config "poly-yatt-config" nil nil nil)

(register-definition-prefixes "poly-yatt-config" '("poly-yatt-"))

;;;***

;;;### (autoloads nil "yatt-js-lint-mode" "yatt-js-lint-mode.el"
;;;;;;  (0 0 0 0))
;;; Generated autoloads from yatt-js-lint-mode.el

(autoload 'yatt-js-lint-mode "yatt-js-lint-mode" "\
Lint yatt-js files

This is a minor mode.  If called interactively, toggle the
`Yatt-Js-Lint mode' mode.  If the prefix argument is positive,
enable the mode, and if it is zero or negative, disable the mode.

If called from Lisp, toggle the mode if ARG is `toggle'.  Enable
the mode if ARG is nil, omitted, or is a positive number.
Disable the mode if ARG is a negative number.

To check whether the minor mode is enabled in the current buffer,
evaluate `yatt-js-lint-mode'.

The mode's hook is called both when the mode is enabled and when
it is disabled.

\(fn &optional ARG)" t nil)

(autoload 'yatt-js-lint-run "yatt-js-lint-mode" nil t nil)

(register-definition-prefixes "yatt-js-lint-mode" '("yatt-"))

;;;***

;;;### (autoloads nil nil ("subdirs.el") (0 0 0 0))

;;;***

(provide 'loaddefs)
;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; loaddefs.el ends here
