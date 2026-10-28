;;; my-git.el --- Git and Magit helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Magitの更新後にdiff-hlとtab-lineの差分表示を更新する。

;;; Code:

(require 'my-tab-line)
(require 'seq)
(require 'tab-bar)

(declare-function tab-router-current-id "tab-router" ())
(declare-function tab-router-find-tab-by-id "tab-router" (id))
(declare-function tab-router--select-destination "tab-router" (destination))

(defvar with-editor-previous-winconf)
(defvar with-editor-post-finish-hook)
(defvar with-editor-post-cancel-hook)
(defvar with-editor-server-window-alist)

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


(defun my/magit-register-commit-message-handler ()
  "Magit の汎用ルール登録後に COMMIT_EDITMSG を Misc に振り分ける。"
  (add-to-list 'with-editor-server-window-alist
               '("/\\.git/COMMIT_EDITMSG\\'" . my/magit-display-commit-message)))


(defun my/magit--return-to-tab (id)
  "ID の Tab が残っていれば、コミット編集開始前の Tab に戻る。"
  (when-let* ((tab (tab-router-find-tab-by-id id))
              (index (seq-position (tab-bar-tabs) tab #'eq)))
    (tab-bar-select-tab (1+ index))))


(defun my/magit-display-commit-message (buffer)
  "コミット編集 BUFFER を Misc Tab に表示する。"
  (let ((origin (tab-router-current-id)))
    (tab-router--select-destination '(:id misc :name "Misc" :directory nil))
    (unless (eq origin 'misc)
      (with-current-buffer buffer
        ;; with-editor が元の Project Tab の配置を Misc に復元しないよう、
        ;; コミット編集前の Misc の配置を保存しておく。
        (setq-local with-editor-previous-winconf
                    (current-window-configuration))
        ;; post-* hooks はバッファ終了後に別の一時バッファで実行される。
        ;; 元の Tab ID をクロージャに保持して復帰先を失わないようにする。
        (when origin
          (let ((return-to-origin
                 (lambda () (my/magit--return-to-tab origin))))
            (add-hook 'with-editor-post-finish-hook return-to-origin nil t)
            (add-hook 'with-editor-post-cancel-hook return-to-origin nil t)))))
    (switch-to-buffer buffer)))

(provide 'my-git)

;;; my-git.el ends here
