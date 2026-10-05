;;; files.el --- File management configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; ファイルとディレクトリの管理に関する設定を置く。

;;; Code:


(require 'my-tab-context)


;; 現在のTabに設定された基準ディレクトリをDiredで開く。
(keymap-global-set "C-x d" #'my/dired)


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
