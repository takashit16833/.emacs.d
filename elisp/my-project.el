;;; my-project.el --- Project-local command runner -*- lexical-binding: t; -*-

;;; Commentary:
;; `.dir-locals.el' に定義したプロジェクト固有のコマンドを、
;; 補完から選択してプロジェクトルートで実行する。
;;
;; コマンドは `my/project-commands' に次の形式で定義する。
;;
;;   (("All tests"
;;     :command "..."
;;     :description "すべてのテストを実行する"))
;;
;; プロジェクト外から実行した場合は `project-current' により
;; 対象プロジェクトを選択できる。

;;; Code:

(require 'project)
(require 'seq)


;;; Variables -------------------------------------------------------


;; Clutchは実行時にautoloadされるため、
;; byte compilerへ関数定義だけを宣言する。
(declare-function clutch-query-console "clutch" (target))

;; ClutchのTRAMP接続元推論を一時的に制御する。
(defvar clutch-tramp-context-policy)

(defvar-local my/project-commands nil
  "現在のプロジェクトで実行できるコマンド一覧。")


(defvar-local my/project-database-connections nil
  "現在のプロジェクトで利用できるデータベース接続一覧。")


;;; Common ----------------------------------------------------------


(defun my/project--get-local-variable (root variable)
  "ROOT の `.dir-locals.el' から VARIABLE の値を取得する。"
  (with-temp-buffer
    (let ((default-directory root)
          ;; TRAMP先でもプロジェクト固有設定を読み込む。
          (enable-remote-dir-locals t))
      ;; 非ファイルバッファなので、ディレクトリローカル変数を
      ;; 明示的に適用する。
      (hack-dir-local-variables-non-file-buffer)
      (symbol-value variable))))


;;; Commands --------------------------------------------------------


(defun my/project-run-command ()
  "現在のプロジェクトに定義されたコマンドを選択して実行する。"
  (interactive)
  (let* ((project (project-current t))
         (root (project-root project))
         (default-directory root)
         (commands (my/project-command--get-project-commands root)))
    (unless commands
      (user-error "コマンド定義がありません"))
    (let* ((completion-extra-properties
            (my/project-command--completion-extra-properties commands))
           (name (completing-read "Command: " commands nil t))
           (options (cdr (assoc name commands)))
           (command (plist-get options :command))
           (prompt (plist-get options :prompt))
           (candidates (plist-get options :candidates)))
      (when prompt
        (let ((input (completing-read prompt candidates nil nil)))
          (when (equal input "")
            (user-error "入力が空です"))
          (setq command
                (concat command " " (shell-quote-argument input)))))
      (pop-to-buffer
       (compile command)))))


(defun my/project-command--get-project-commands (root)
  "ROOT の `.dir-locals.el' からプロジェクトコマンド一覧を取得する。"
  (my/project--get-local-variable root 'my/project-commands))


(defun my/project-command--completion-extra-properties (commands)
  "COMMANDS の説明を補完候補に表示するための設定を返す。"
  (list
   :annotation-function
   (lambda (name)
     (let ((description
            (plist-get
             (cdr (assoc name commands))
             :description)))
       (concat "\t" description)))))


(defun my/project-commands-safe-p (commands)
  "COMMANDS がプロジェクトコマンドとして正しい形式なら非nilを返す。

各コマンドは名前、`:command'、`:description' を持ち、
それぞれの値は文字列でなければならない。"
  (and
   (listp commands)
   (seq-every-p
    (lambda (command)
      (and
       (listp command)
       (let ((name (car command))
             (body (cdr command)))
         (and
          (plistp body)
          (stringp name)
          (stringp (plist-get body :command))
          (stringp (plist-get body :description))
	  (or (not (plist-member body :prompt))
	      (stringp (plist-get body :prompt)))
	  (or (not (plist-member body :candidates))
	      (let ((candidates (plist-get body :candidates)))
		(and (listp candidates)
		     (seq-every-p #'stringp candidates))))))))
    commands)))


;; `.dir-locals.el' の `my/project-commands' は、
;; 上記の形式を満たす場合のみ安全なローカル変数として扱う。
(put 'my/project-commands
     'safe-local-variable
     #'my/project-commands-safe-p)


;;; Database --------------------------------------------------------


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


(provide 'my-project)

;;; my-project.el ends here
