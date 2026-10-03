;;; project.el --- Project configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Project機能とプロジェクト固有の設定を置く。

;;; Code:


(require 'project)
(require 'my-project)


;; Project内のファイルを検索して開く。
(keymap-global-set "s-p" #'project-find-file)


;; Project commandsを実行する。
(keymap-global-set "C-x p t" #'my/project-run-command)

;; project-switch-projectの選択肢を設定する。
(setopt project-switch-commands
        '((project-find-file "Find file")
          (project-find-regexp "Find regexp")
          (project-any-command "Other")))


;; project-switch-projectの選択肢にMagitを追加する。
(add-to-list 'project-switch-commands
             '(magit-project-status "Magit" ?m)
             t)


;;; project.el ends here
