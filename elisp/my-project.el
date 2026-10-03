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


(defvar-local my/project-commands nil
  "現在のプロジェクトで実行できるコマンド一覧。")


(defun my/project-run-command ()
  "現在のプロジェクトに定義されたコマンドを選択して実行する。

コマンドはプロジェクトの `.dir-locals.el' にある
`my/project-commands' から取得し、プロジェクトルートを
作業ディレクトリとして `compile' で実行する。"
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
           (command
            (plist-get
             (cdr (assoc name commands))
             :command)))
      (pop-to-buffer
       (compile command)))))


(defun my/project-command--get-project-commands (root)
  "ROOT の `.dir-locals.el' からプロジェクトコマンド一覧を取得する。"
  (with-temp-buffer
    (let ((default-directory root))
      ;; 非ファイルバッファなので、ディレクトリローカル変数を
      ;; 明示的に適用する。
      (hack-dir-local-variables-non-file-buffer)
      my/project-commands)))


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
          (stringp (plist-get body :description))))))
    commands)))


;; `.dir-locals.el' の `my/project-commands' は、
;; 上記の形式を満たす場合のみ安全なローカル変数として扱う。
(put 'my/project-commands
     'safe-local-variable
     #'my/project-commands-safe-p)


(provide 'my-project)

;;; my-project.el ends here
