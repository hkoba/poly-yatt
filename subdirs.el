;;
;;
;;

(let ((dir (or (and load-file-name (file-name-directory load-file-name))
	       default-directory))
      (ext "\\.ytjs\\'"))
  (add-to-list 'load-path dir)
  (load (concat dir "loaddefs.el"))
  (add-to-list 'auto-mode-alist
               (cons ext 'poly-yatt-html-mode)))
