;;; init.el --- CLI Emacs configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 各設定ファイルを読み込むためのエントリーポイント。

;;; Code:

(load (expand-file-name "config/packages.el" user-emacs-directory))
(load (expand-file-name "config/basic.el" user-emacs-directory))
(load (expand-file-name "config/terminal.el" user-emacs-directory))
(load (expand-file-name "config/ui.el" user-emacs-directory))
(load (expand-file-name "config/editor.el" user-emacs-directory))
(load (expand-file-name "config/development.el" user-emacs-directory))
(load (expand-file-name "config/org.el" user-emacs-directory))

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(retro-hacker-blue-theme undo-fu))
 '(package-vc-selected-packages
   '((retro-hacker-blue-theme :url
			      "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
