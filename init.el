;;; init.el --- CLI Emacs configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 各設定ファイルを読み込むためのエントリーポイント。

;;; Code:

(load (expand-file-name "config/basic.el" user-emacs-directory))
(load (expand-file-name "config/terminal.el" user-emacs-directory))
(load (expand-file-name "config/ui.el" user-emacs-directory))
(load (expand-file-name "config/editor.el" user-emacs-directory))
(load (expand-file-name "config/development.el" user-emacs-directory))
(load (expand-file-name "config/org.el" user-emacs-directory))

;;; init.el ends here
