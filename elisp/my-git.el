;;; my-git.el --- Git and Magit helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Magitの更新後にdiff-hlとtab-lineの差分表示を更新する。

;;; Code:

(require 'my-tab-line)
(require 'my-tab-routing)
(require 'seq)
(require 'tab-bar)

(declare-function tab-router-current-id "tab-router" ())
(declare-function tab-router-find-tab-by-id "tab-router" (id))

(defvar with-editor-mode)
(defvar with-editor-previous-winconf)
(defvar with-editor-pre-finish-hook)
(defvar with-editor-pre-cancel-hook)
(defvar with-editor-post-finish-hook)
(defvar with-editor-post-cancel-hook)

(defvar-local my/git-editor-origin-tab nil
  "コミット編集が開始された時点の Tab ID。")

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



(defun my/git-editor-return-to-tab (id)
  "元の ID を持つ Tab が残っていればそこへ戻る。"
  (when-let* ((tab (tab-router-find-tab-by-id id))
              (index (seq-position (tab-bar-tabs) tab #'eq)))
    (tab-bar-select-tab (1+ index))))


(defun my/git-editor-skip-window-restore ()
  "Misc 内で終了する with-editor が別 Tab の配置を復元しないようにする。"
  (when (eq (tab-router-current-id) 'misc)
    (setq-local with-editor-previous-winconf nil)))


(defun my/git-editor-setup ()
  ".git 配下の with-editor バッファの終了時に元の Tab へ戻る準備をする。"
  (when (and with-editor-mode
             buffer-file-name
             (my/route-git-internal buffer-file-name)
             (not (local-variable-p 'my/git-editor-origin-tab)))
    ;; この hook は server-switch-buffer による表示・ルーティング前に走る。
    (let ((origin (tab-router-current-id)))
      (setq-local my/git-editor-origin-tab origin)
      (add-hook 'with-editor-pre-finish-hook
                #'my/git-editor-skip-window-restore nil t)
      (add-hook 'with-editor-pre-cancel-hook
                #'my/git-editor-skip-window-restore nil t)
      ;; post-* hooks は終了後に別の一時バッファで実行されるため、
      ;; バッファローカル変数ではなくクロージャで戻り先を保持する。
      (when (and origin (not (eq origin 'misc)))
        (let ((return-to-origin
               (lambda () (my/git-editor-return-to-tab origin))))
          (add-hook 'with-editor-post-finish-hook return-to-origin nil t)
          (add-hook 'with-editor-post-cancel-hook return-to-origin nil t))))))


(provide 'my-git)

;;; my-git.el ends here
