;;; init.el --- CLI Emacs configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 各設定ファイルを読み込むためのエントリーポイント。

;;; Code:

;; Emacs Lisp を置くディレクトリ。
(add-to-list 'load-path
             (expand-file-name "elisp" user-emacs-directory))

;; 設定を読み込む。
(load (expand-file-name "config/packages.el" user-emacs-directory))
(load (expand-file-name "config/appearance.el" user-emacs-directory))
(load (expand-file-name "config/core.el" user-emacs-directory))
(load (expand-file-name "config/window.el" user-emacs-directory))
(load (expand-file-name "config/completion.el" user-emacs-directory))
(load (expand-file-name "config/terminal.el" user-emacs-directory))
(load (expand-file-name "config/editing.el" user-emacs-directory))
(load (expand-file-name "config/development.el" user-emacs-directory))
(load (expand-file-name "config/project.el" user-emacs-directory))
(load (expand-file-name "config/git.el" user-emacs-directory))
(load (expand-file-name "config/navigation.el" user-emacs-directory))
(load (expand-file-name "config/files.el" user-emacs-directory))
(load (expand-file-name "config/org.el" user-emacs-directory))

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(avy browsing-history bufferlo cape clutch embark embark-consult
	 one-dark-blue-theme pgsql retro-hacker-blue-theme tab-router
	 undo-fu))
 '(package-vc-selected-packages
   '((retro-hacker-blue-theme :url
			      "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git")))
 '(safe-local-variable-directories '("/Users/suzukitakashi/rag-lab/")))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
