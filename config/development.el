;;; development.el --- Development configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; プログラミング、Git、言語固有の開発設定を置く。

;;; Code:


;; Tree-sitterの色分けを最大レベルにする。
(setq treesit-font-lock-level 4)


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


;; luaでtree-sitterを有効にする。
(use-package lua-ts-mode
  :ensure nil
  :mode ("\\.lua\\'" . lua-ts-mode))


;;; development.el ends here
