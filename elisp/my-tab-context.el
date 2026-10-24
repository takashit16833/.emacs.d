;;; my-tab-context.el --- Commands using the current Tab context -*- lexical-binding: t; -*-

;;; Commentary:
;; Tab Router が現在のTabに保存している基準ディレクトリを使って、
;; Project・Magit・Diredなどのコマンドを実行する。

;;; Code:

(require 'project)

(declare-function tab-router-current-directory "tab-router")
(declare-function magit-status "magit-status")
(declare-function dirvish "dirvish" (&optional path))
(declare-function dirvish-subtree-expand-to "dirvish-subtree" (target))


(defun my/tab-context-directory ()
  "現在の操作で基準にするディレクトリを返す。

`project-switch-project' などによって
`project-current-directory-override' が設定されている場合は、
そのディレクトリを優先する。

それ以外では、現在のTabにTab Routerが保存している
基準ディレクトリを返す。"
  (or project-current-directory-override
      (when (fboundp 'tab-router-current-directory)
        (tab-router-current-directory))))


(defun my/project-find-file (&optional include-all)
  "現在のTabを基準に `project-find-file' を実行する。

Tabに基準ディレクトリが設定されていない場合は、
通常の `project-find-file' と同じように現在のbufferから
Projectを判定する。"
  (interactive "P")
  (let ((project-current-directory-override
         (my/tab-context-directory)))
    (project-find-file include-all)))


(defun my/magit-status ()
  "現在のTabを基準に `magit-status' を開く。

Tabに基準ディレクトリが設定されていない場合は、
通常の `magit-status' を実行する。"
  (interactive)
  (if-let* ((directory (my/tab-context-directory)))
      (magit-status directory)
    (call-interactively #'magit-status)))


(defun my/project-dirvish ()
  "現在のTabを基準にDirvishを開き、編集中のファイルを選択する。"
  (interactive)
  (let ((file buffer-file-name)
        (root (or (my/tab-context-directory) default-directory)))
    (dirvish root)
    (when (and file
               (file-in-directory-p file root)
               (derived-mode-p 'dired-mode))
      (require 'dirvish-subtree)
      (let ((target-position
             (save-excursion
               (goto-char (point-min))
               (when (dirvish-subtree-expand-to
                      (expand-file-name file))
                 (point-marker)))))
        (when target-position
          (goto-char target-position)
          (set-marker target-position nil))))))


(provide 'my-tab-context)

;;; my-tab-context.el ends here
