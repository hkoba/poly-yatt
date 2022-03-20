;;
;;
;;

(let ((dir (or (and load-file-name (file-name-directory load-file-name))
	       default-directory)))
  (add-to-list 'load-path dir)
  (load (concat dir "loaddefs.el")))
