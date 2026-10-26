;;; init.el --- CLI Emacs configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 各設定ファイルを読み込むためのエントリーポイント。

;;; Code:

;; Emacs Lisp を置くディレクトリ。
(add-to-list 'load-path
             (expand-file-name "elisp" user-emacs-directory))

;; 設定を読み込む。
(load (expand-file-name "config/packages" user-emacs-directory))
(load (expand-file-name "config/appearance" user-emacs-directory))
(load (expand-file-name "config/core" user-emacs-directory))
(load (expand-file-name "config/window" user-emacs-directory))
(load (expand-file-name "config/completion" user-emacs-directory))
(load (expand-file-name "config/terminal" user-emacs-directory))
(load (expand-file-name "config/editing" user-emacs-directory))
(load (expand-file-name "config/development" user-emacs-directory))
(load (expand-file-name "config/languages" user-emacs-directory))
(load (expand-file-name "config/formatting" user-emacs-directory))
(load (expand-file-name "config/database" user-emacs-directory))
(load (expand-file-name "config/project" user-emacs-directory))
(load (expand-file-name "config/git" user-emacs-directory))
(load (expand-file-name "config/navigation" user-emacs-directory))
(load (expand-file-name "config/files" user-emacs-directory))
(load (expand-file-name "config/org" user-emacs-directory))
(load (expand-file-name "config/org-appearance" user-emacs-directory))
(load (expand-file-name "config/org-agenda" user-emacs-directory))
(load (expand-file-name "config/org-pomodoro" user-emacs-directory))

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ignored-local-variable-values '((my-haskell-simple-indent-offset . 2)))
 '(package-selected-packages
   '(avy browsing-history bufferlo cape clutch embark embark-consult
	 markdown-indent-mode markdown-ts-appear one-dark-blue-theme
	 org-appear org-modern org-pomodoro org-super-agenda pgsql
	 retro-hacker-blue-theme tab-router))
 '(package-vc-selected-packages
   '((retro-hacker-blue-theme :url
			      "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git")))
 '(safe-local-variable-directories
   '("/Users/suzukitakashi/hands-on-llm/"
     "/Users/suzukitakashi/ai-support-desk/"
     "/Users/suzukitakashi/rag-lab/")))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
