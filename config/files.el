;;; files.el --- File management configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; ファイルとディレクトリの管理に関する設定を置く。

;;; Code:


;; Diredを拡張したファイルマネージャ。
(use-package dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-attributes
   '(subtree-state
     nerd-icons
     collapse
     file-modes
     file-time
     file-size
     git-msg)))


;;; files.el ends here
