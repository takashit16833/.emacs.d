;;; my-project-test.el --- Tests for my-project -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-project' のテスト。

;;; Code:

(require 'cl-lib)
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



;;; my/project-database-connections-safe-p -------------------------------


(ert-deftest my/project-database-connections-safe-p-valid ()
  "正しい形式のデータベース接続を安全と判定すること。"
  (should
   (my/project-database-connections-safe-p
    '(("rag-lab"
       :backend pg
       :host "127.0.0.1"
       :port 5432
       :user "rag_lab"
       :database "rag_lab"
       :password "rag_lab"
       :tramp-default-directory "/docker:rag-lab-dev:/")))))


(ert-deftest my/project-database-connections-safe-p-backend-required ()
  "`:backend' が存在しない接続は安全と判定しないこと。"
  (should-not
   (my/project-database-connections-safe-p
    '(("database"
       :host "127.0.0.1"
       :port 5432)))))


(ert-deftest my/project-database-connections-safe-p-port-must-be-integer ()
  "`:port' が整数でない接続は安全と判定しないこと。"
  (should-not
   (my/project-database-connections-safe-p
    '(("database"
       :backend pg
       :port "5432")))))


(ert-deftest my/project-database-connections-safe-p-validates-all-connections ()
  "複数の接続定義に不正な接続が含まれていれば安全と判定しないこと。"
  (should-not
   (my/project-database-connections-safe-p
    '(("valid"
       :backend pg
       :port 5432)
      ("invalid"
       :backend pg
       :password 1234)))))


(ert-deftest my/project-database-connections-safe-p-ssh-host-must-be-string ()
  "`:ssh-host' が文字列でない接続は安全と判定しないこと。"
  (should-not
   (my/project-database-connections-safe-p
    '(("database"
       :backend pg
       :ssh-host 1234)))))


(ert-deftest my/project-database-connections-safe-p-tramp-directory-must-be-string ()
  "`:tramp-default-directory' が文字列でない接続は安全と判定しないこと。"
  (should-not
   (my/project-database-connections-safe-p
    '(("database"
       :backend pg
       :tramp-default-directory 1234)))))


;;; my/project-open-database ----------------------------------------------


(ert-deftest my/project-open-database-opens-selected-connection ()
  "選択した接続をプロジェクトルートからClutchで開くこと。"
  (let ((root (file-name-as-directory "/tmp/my-project-test"))
        (original-require (symbol-function 'require))
        (clutch-tramp-context-policy 'ask)
        required-policy
        opened-directory
        opened-policy
        opened-target)
    (cl-letf (((symbol-function 'project-current)
               (lambda (&rest _args)
                 'project))
              ((symbol-function 'project-root)
               (lambda (_project)
                 root))
              ((symbol-function 'my/project-database--get-connections)
               (lambda (_root)
                 '(("primary"
                    :backend pg
                    :host "127.0.0.1"
                    :port 5432
                    :user "user"
                    :database "primary")
                   ("secondary"
                    :backend pg
                    :host "db"
                    :port 5432
                    :user "user"
                    :database "secondary"
                    :tramp-default-directory "/docker:secondary-dev:/"))))
              ((symbol-function 'completing-read)
               (lambda (prompt collection &rest _args)
                 (should (equal prompt "Database: "))
                 (should
                  (equal
                   (mapcar #'car collection)
                   '("primary" "secondary")))
                 "secondary"))
              ((symbol-function 'require)
               (lambda (feature &optional filename noerror)
                 (if (eq feature 'clutch)
                     (progn
                       (setq required-policy
                             (symbol-value 'clutch-tramp-context-policy))
                       feature)
                   (funcall original-require
                            feature
                            filename
                            noerror))))
              ((symbol-function 'clutch-query-console)
               (lambda (target)
                 (setq opened-directory default-directory
                       opened-policy
                       (symbol-value 'clutch-tramp-context-policy)
                       opened-target target))))
      (my/project-open-database))
    ;; Clutchの読み込みはTRAMPポリシーを束縛する前に行う。
    (should (eq required-policy 'ask))
    (should (equal opened-directory root))
    (should-not opened-policy)
    (should (eq clutch-tramp-context-policy 'ask))
    (should
     (equal
      opened-target
      '(:name "secondary"
        :params (:backend pg
                 :host "db"
                 :port 5432
                 :user "user"
                 :database "secondary"
                 :tramp-default-directory "/docker:secondary-dev:/"))))))


(ert-deftest my/project-open-database-no-connections ()
  "データベース接続定義がなければエラーにすること。"
  (cl-letf (((symbol-function 'project-current)
             (lambda (&rest _args)
               'project))
            ((symbol-function 'project-root)
             (lambda (_project)
               "/tmp/my-project-test/"))
            ((symbol-function 'my/project-database--get-connections)
             (lambda (_root)
               nil)))
    (should-error
     (my/project-open-database)
     :type 'user-error)))


;;; my-project-test.el ends here
