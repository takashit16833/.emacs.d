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
  (should-not
   (my/project-commands-safe-p '((1 :command "test" :description "desc")))))


(ert-deftest my/project-commands-safe-p-command-missing ()
  "`:command' が存在しない場合は安全と判定しないこと。"
  (should-not
   (my/project-commands-safe-p '(("name" :description "desc")))))


(ert-deftest my/project-commands-safe-p-command-not-string ()
  "`:command' の値が文字列でない場合は安全と判定しないこと。"
  (should-not
   (my/project-commands-safe-p '(("name" :command 1 :description "desc")))))


(ert-deftest my/project-commands-safe-p-description-missing ()
  "`:description' が存在しない場合は安全と判定しないこと。"
  (should-not
   (my/project-commands-safe-p '(("name" :command "test")))))


(ert-deftest my/project-commands-safe-p-description-not-string ()
  "`:description' の値が文字列でない場合は安全と判定しないこと。"
  (should-not
   (my/project-commands-safe-p '(("name" :command "test" :description 1)))))


;;; my/project-command--get-project-commands -------------------------------


(ert-deftest my/project-command--get-project-commands-defined ()
  "ROOT に定義されたプロジェクトコマンドを返すこと。"
  (let ((root (file-name-as-directory (make-temp-file "my-project-test-" t))))
    (unwind-protect
	(let ((file (expand-file-name ".dir-locals.el" root)))
	  (with-temp-file file
	    (prin1
	     '((nil . ((my/project-commands
			. (("name"
			    :command "test command"
			    :description "test description"))))))
	     (current-buffer)))
	    
	  (let ((commands
		 (my/project-command--get-project-commands root)))
	    (should
	     (equal
	      commands
	      '(("name" :command "test command" :description "test description")))))))
    (delete-directory root t)))


(ert-deftest my/project-command--get-project-commands-not-defined ()
  "ROOT にプロジェクトコマンドが定義されていなければ nil を返すこと。"
  (let ((root
         (file-name-as-directory
          (make-temp-file "my-project-test-" t))))
    (unwind-protect
        (should-not
         (my/project-command--get-project-commands root))
      (delete-directory root t))))


(ert-deftest my/project-command--get-project-commands-uses-root ()
  "現在位置ではなく指定された ROOT のプロジェクトコマンドを返すこと。"
  (let* ((parent
          (file-name-as-directory
           (make-temp-file "my-project-test-" t)))
         (current-root
          (file-name-as-directory
           (expand-file-name "current" parent)))
         (target-root
          (file-name-as-directory
           (expand-file-name "target" parent))))
    (unwind-protect
        (progn
          (make-directory current-root)
          (make-directory target-root)
          (with-temp-file
              (expand-file-name ".dir-locals.el" target-root)
            (prin1
             '((nil . ((my/project-commands
                        . (("target"
                            :command "target command"
                            :description "target description"))))))
             (current-buffer)))
          (let ((default-directory current-root)
                (commands
                 (my/project-command--get-project-commands target-root)))
            (should
             (equal
              commands
              '(("target"
                 :command "target command"
                 :description "target description"))))))
      (delete-directory parent t))))


;;; my/project-command--completion-extra-properties ------------------------


(ert-deftest my/project-command--completion-extra-properties-description ()
  "コマンド名に対応する説明を補完候補の注釈として返すこと。"
  (let* ((commands
          '(("first"
             :command "first command"
             :description "first description")
            ("second"
             :command "second command"
             :description "second description")))
         (properties
          (my/project-command--completion-extra-properties commands))
         (annotation-function
          (plist-get properties :annotation-function)))
    (should
     (equal
      (funcall annotation-function "second")
      "\tsecond description"))))


;;; my-project-test.el ends here
