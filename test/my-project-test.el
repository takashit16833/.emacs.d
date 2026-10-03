;;; my-project-test.el --- Tests for my-project -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-project' のテスト。

;;; Code:

(require 'ert)
(require 'my-project)


;;; my/project-commands-safe-p ----------------------------------------------


(ert-deftest my/project-commands-safe-p-valid ()
  "正しい形式のプロジェクトコマンドを安全と判定すること。"
  (should
   (my/project-commands-safe-p
    '(("test"
       :command "make test"
       :description "テストを実行する")))))


;;; my/project-command--get-project-commands -------------------------------



;;; my/project-command--completion-extra-properties ------------------------



;;; my-project-test.el ends here
