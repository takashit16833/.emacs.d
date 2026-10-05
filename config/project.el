;;; project.el --- Project configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Project機能とプロジェクト固有の設定を置く。

;;; Code:


(require 'project)
(require 'my-project)


;; Project内のファイルを検索して開く。
(keymap-global-set "s-p" #'project-find-file)


;; Project commandsを実行する。
(keymap-set project-prefix-map "t" #'my/project-run-command)


;; project-switch-projectの選択肢を設定する。
(setopt project-switch-commands
        '((project-find-file "Find file")
          (project-find-regexp "Find regexp")
          (my/project-run-command "Run command" ?t)
          (magit-project-status "Magit" ?m)
          (project-any-command "Other")))


;;; project.el ends here
