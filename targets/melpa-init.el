
(require 'package)

(setq package-user-dir (expand-file-name (format ".ELPA/%s" emacs-version))
      package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))

(let ((env (getenv "ELPA_PATH")))
  (when env
    (setq package-directory-list
          (append (split-string env ":")
                  package-directory-list))))

(package-initialize)
