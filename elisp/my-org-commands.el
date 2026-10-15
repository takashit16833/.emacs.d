;;; my-org-commands.el --- Personal Org commands -*- lexical-binding: t; -*-

;;; Commentary:
;; Org で使用する個人用コマンドを定義する。

;;; Code:

(defvar org-default-notes-file)

(declare-function org-capture "org-capture" (&optional goto keys))
(declare-function org-insert-todo-subheading "org" (arg))


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


(defun my/org-insert-child-task ()
  "現在の見出しの子タスクとして TODO を追加する。"
  (interactive)
  (org-insert-todo-subheading nil))


(provide 'my-org-commands)

;;; my-org-commands.el ends here
