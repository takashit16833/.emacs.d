;;; my-git.el --- Git and Magit helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Magitの更新後にdiff-hlとtab-lineの差分表示を更新する。

;;; Code:

(require 'my-tab-line)

(declare-function magit-file-status "magit-git" (&rest args))
(declare-function magit-toplevel "magit-git" (&optional directory))
(declare-function diff-hl-magit-post-refresh "diff-hl" ())


(defun my/magit-refresh-tab-line-git-status ()
  "Magitの更新後にtab-lineのGit差分状態を更新する。"
  (let ((root (magit-toplevel))
        modified-files)
    (when root
      ;; リポジトリ全体を1回だけ確認し、開いているbufferへ結果を配る。
      ;; 未追跡ファイルは従来どおりGit差分色の対象外にする。
      (dolist (status (magit-file-status "--untracked-files=no"))
        (push (car status) modified-files)
        ;; rename/copyは元のパスも返るため、両方を対象にする。
        (when (cadr status)
          (push (cadr status) modified-files)))
      (my/tab-line-update-git-modified-cache root modified-files))))


;; diff-hlが定義する変数を、遅延読み込み前に宣言する。
(defvar diff-hl-disable-on-remote)

(defun my/diff-hl-magit-post-refresh ()
  "Magitの更新後にdiff-hlの表示を更新する。"
  ;; 通常のリモート自動更新は抑止し、Magitの明示的な更新時だけ
  ;; remote制限を一時的に解除する。
  (let ((diff-hl-disable-on-remote nil))
    (diff-hl-magit-post-refresh)))


(provide 'my-git)

;;; my-git.el ends here
