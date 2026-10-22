;;; my-org-commands.el --- Personal Org commands -*- lexical-binding: t; -*-

;;; Commentary:
;; Org で使用する個人用コマンドを定義する。

;;; Code:

(defvar org-default-notes-file)

(declare-function org-capture "org-capture" (&optional goto keys))
(declare-function org-end-of-meta-data "org" (&optional full))
(declare-function org-insert-todo-subheading "org" (arg))
(declare-function org-timestamp-inactive "org" (&optional arg))


(defvar my/org-home--return-buffer nil
  "Org Home を開く前に表示していたバッファ。")


(defun my/org-home--current-p ()
  "現在のバッファが Org Home なら non-nil を返す。"
  (and buffer-file-name
       (equal (expand-file-name buffer-file-name)
              (expand-file-name org-default-notes-file))))


(defun my/org-home-toggle ()
  "Org Home と、開く前のバッファを切り替える。"
  (interactive)
  (if (my/org-home--current-p)
      (let ((return-buffer my/org-home--return-buffer))
        (setq my/org-home--return-buffer nil)
        (if (buffer-live-p return-buffer)
            (switch-to-buffer return-buffer)
          (switch-to-buffer nil)))
    (setq my/org-home--return-buffer (current-buffer))
    (find-file org-default-notes-file)))


(defun my/org-capture-inbox ()
  "Inbox 用テンプレートで Org Capture を開始する。"
  (interactive)
  (org-capture nil "i"))


(defun my/org-insert-created ()
  "現在の見出しのメタ情報直後に CREATED と現在時刻を追加する。"
  (interactive)
  (save-excursion
    (org-end-of-meta-data)
    (if (looking-at-p "[ \t]*CREATED:[ \t]")
        (user-error "CREATED は既に設定されています")
      (insert "  CREATED: ")
      ;; C-u C-u 相当で、日時選択を開かず現在日時を挿入する。
      (org-timestamp-inactive '(16))
      (insert "\n"))))


(defun my/org-insert-child-task ()
  "現在の見出しの末尾に子タスクを追加する。"
  (interactive)
  (let ((org-insert-heading-respect-content t))
    (org-insert-todo-subheading nil)))


;;; Mermaid blocks

(declare-function org-block-map "org" (function &optional start end))
(declare-function org-element-at-point "org-element" (&optional epom cached-only))
(declare-function org-element-type "org-element-ast" (node &optional anonymous))
(declare-function org-element-property "org-element-ast"
                  (property node &optional dflt force-undefer))
(declare-function org-fold-hide-block-toggle "org-fold"
                  (&optional force no-error element))

(defun my/org-hide-mermaid-blocks ()
  "Fold Mermaid source blocks without hiding other Org blocks."
  (org-block-map
   (lambda ()
     (let ((element (org-element-at-point)))
       (when (and (eq (org-element-type element) 'src-block)
                  (equal (org-element-property :language element) "mermaid"))
         (org-fold-hide-block-toggle 'hide nil element))))))

(provide 'my-org-commands)

;;; my-org-commands.el ends here
