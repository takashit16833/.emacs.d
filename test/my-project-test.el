;;; my-project-test.el --- Tests for my-project -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-project' のテスト。

;;; Code:

(require 'ert)
(require 'my-project)
(require 'seq)

;;; my/project-commands-safe-p ----------------------------------------------


(ert-deftest my/project-commands-safe-p-valid ()
  "正しい形式のプロジェクトコマンドを安全と判定すること。"
  (should
   (my/project-commands-safe-p
    '(("test"
       :command "make test"
       :description "テストを実行する")))))


(ert-deftest my/project-commands-safe-p-empty ()
  "空のコマンド一覧は安全と判定すること。"
  (should
   (my/project-commands-safe-p nil)))


(ert-deftest my/project-commands-safe-p-commands-not-list ()
  "COMMANDS 全体がリストでない場合は安全と判定しないこと。"
  (should-not
   (my/project-commands-safe-p "not a list")))


(ert-deftest my/project-commands-safe-p-command-not-list ()
  "各コマンドがリストでない場合は安全と判定しないこと。"
  (should-not
    (my/project-commands-safe-p '("not a list"))))


(ert-deftest my/project-commands-safe-p-body-not-plist ()
  "コマンド本体が plist でない場合は安全と判定しないこと。"
  (should-not
   (my/project-commands-safe-p '(("name"  :command . "not a plist")))))


(ert-deftest my/project-commands-safe-p-name-not-string ()
  "コマンド名が文字列でない場合は安全と判定しないこと。"
  )


(ert-deftest my/project-commands-safe-p-command-missing ()
  "`:command' が存在しない場合は安全と判定しないこと。"
  )


(ert-deftest my/project-commands-safe-p-command-not-string ()
  "`:command' の値が文字列でない場合は安全と判定しないこと。"
  )


(ert-deftest my/project-commands-safe-p-description-missing ()
  "`:description' が存在しない場合は安全と判定しないこと。"
  )


(ert-deftest my/project-commands-safe-p-description-not-string ()
  "`:description' の値が文字列でない場合は安全と判定しないこと。"
  )


;;; my/project-command--get-project-commands -------------------------------



;;; my/project-command--completion-extra-properties ------------------------



;;; my-project-test.el ends here
