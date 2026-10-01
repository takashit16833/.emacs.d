
;;; development.el --- Development configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; プログラミング、Git、言語固有の開発設定を置く。

;;; Code:


;; Project内のファイルを検索して開く。
(keymap-global-set "s-p" #'project-find-file)


;; project-switch-projectの選択肢を変更する
(setopt project-switch-commands
         '((project-find-file "Find file")
          (project-find-regexp "Find regexp")
          (project-any-command "Other")))


 ;; project-switch-projectの選択肢にMagitを追加する。
(add-to-list 'project-switch-commands
             '(magit-project-status "Magit" ?m)
             t)


;; プロジェクトの.editorconfigを反映する。
(use-package editorconfig
  :ensure nil
  :hook (after-init . editorconfig-mode))


;;; development.el ends here
