
(require 'poly-yatt-html)
(require 'polymode-test-utils)
(load "../loaddefs");; For autoload
;; (pm-test-get-file "t000.ytjs")

(pm-test-run-on-file poly-yatt-html-mode "t000.ytjs"
  (switch-to-buffer (current-buffer))
  (goto-char 1)
  (pm-switch-to-buffer)
  (should (equal '(1 . 14) (pm-innermost-range (point))))
  (should (equal '(14 . 86) (poly-yatt-multipart-boundary 1)))

  (should (equal '(14 . 86) (pm-innermost-range (point))))

  (goto-char 109)
  (should (equal '(86 . 112) (pm-innermost-range (point))))

)
