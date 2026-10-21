;;; my-project-database.el --- Project-local database connections -*- lexical-binding: t; -*-

;;; Commentary:
;; `.dir-locals.el' に定義したDB接続を検証し、Clutchで開く。

;;; Code:

(require 'my-project)
(require 'seq)

;; Clutchは実行時にautoloadされるため、
;; byte compilerへ関数定義だけを宣言する。
(declare-function clutch-query-console "clutch" (target))

;; ClutchのTRAMP接続元推論を一時的に制御する。
(defvar clutch-tramp-context-policy)

(defvar-local my/project-database-connections nil
  "現在のプロジェクトで利用できるデータベース接続一覧。")


(defun my/project-database--get-connections (root)
  "ROOT の `.dir-locals.el' からデータベース接続一覧を取得する。"
  (my/project--get-local-variable
   root
   'my/project-database-connections))


(defun my/project-open-database ()
  "現在のプロジェクトに定義されたデータベースをClutchで開く。

接続情報はプロジェクトの `.dir-locals.el' にある
`my/project-database-connections' から取得する。"
  (interactive)
  (let* ((project (project-current t))
         (root (project-root project))
         (connections
          (my/project-database--get-connections root)))
    (unless connections
      (user-error "データベース接続定義がありません"))
    (let* ((name
            (completing-read
             "Database: "
             connections
             nil
             t))
           (params
            (copy-sequence
             (cdr (assoc name connections)))))
      ;; Clutchが定義する変数を動的束縛する前に本体を読み込む。
      ;; `defcustom' を束縛中に評価しないため、autoloadには任せない。
      (require 'clutch)

      ;; Clutchには保存済み接続ではなくad-hoc接続として渡す。
      ;; これによりグローバルなclutch-connection-alistを使用しない。
      (let ((default-directory root)
            ;; 現在のTRAMPバッファから接続経路を推測しない。
            ;; 明示された:ssh-hostや:tramp-default-directoryは
            ;; Clutchがそのまま接続経路として使用する。
            (clutch-tramp-context-policy nil))
        (clutch-query-console
         (list :name name
               :params params))))))


(defun my/project-database-connections-safe-p (connections)
  "CONNECTIONS がプロジェクトDB接続として正しい形式なら非nilを返す。"
  (and
   (listp connections)
   (seq-every-p
    (lambda (connection)
      (and
       (listp connection)
       (stringp (car connection))
       (let ((params (cdr connection)))
         (and
          (plistp params)
          (plist-member params :backend)
          (symbolp (plist-get params :backend))
          (or
           (not (plist-member params :host))
           (stringp (plist-get params :host)))
          (or
           (not (plist-member params :port))
           (integerp (plist-get params :port)))
          (or
           (not (plist-member params :user))
           (stringp (plist-get params :user)))
          (or
           (not (plist-member params :database))
           (stringp (plist-get params :database)))
          (or
           (not (plist-member params :password))
           (stringp (plist-get params :password)))
          (or
           (not (plist-member params :ssh-host))
           (stringp (plist-get params :ssh-host)))
          (or
           (not (plist-member params :tramp-default-directory))
           (stringp (plist-get params :tramp-default-directory)))))))
    connections)))


(put 'my/project-database-connections
     'safe-local-variable
     #'my/project-database-connections-safe-p)


(provide 'my-project-database)

;;; my-project-database.el ends here

