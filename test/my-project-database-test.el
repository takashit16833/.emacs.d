;;; my-project-database-test.el --- Project database tests -*- lexical-binding: t; -*-

;;; Commentary:
;; プロジェクトローカルなDB接続の検証とClutch起動を確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-project-database)

;; Clutch本体を読み込まないテストでも動的束縛として扱う。
(defvar clutch-tramp-context-policy)


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


;;; my-project-database-test.el ends here

