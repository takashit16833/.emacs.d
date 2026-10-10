;;; git.el --- Git configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Git と Magit に関する設定を置く。

;;; Code:

(require 'my-tab-context)
(require 'my-ui)

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


(defun my/diff-hl-magit-post-refresh ()
  "Magitの更新後にdiff-hlの表示を更新する。"
  ;; TRAMPでは起動時だけdiff-hlを抑止しているため、
  ;; Magitから明示的に更新するときはremote制限を解除する。
  (let ((diff-hl-disable-on-remote nil))
    (diff-hl-magit-post-refresh)))


;; 編集中のファイルにGitとの差分を表示する。
(use-package diff-hl
  :ensure t
  :demand t
  
  :custom
  ;; TRAMPでは自動的なGit問い合わせを避ける。
  ;; リモートの差分表示が必要な場合はファイルごとに有効化する。
  (diff-hl-disable-on-remote t)

  :bind
  (:map diff-hl-mode-map
        ("<f5>"   . diff-hl-next-hunk)
        ("S-<f5>" . diff-hl-previous-hunk))

  :config
  ;; 端末ではfringeを表示できないため、左marginに差分を表示する。
  (require 'diff-hl-margin)

  ;; 差分を1文字の縦線で表示する。
  (setopt diff-hl-margin-symbols-alist
          '((insert . "│")
            (change . "│")
            (delete . "│")
            (unknown . "?")
            (ignored . "i")
            (reference . " ")))

  ;; global-diff-hl-modeを有効にする前にmargin表示へ切り替える。
  ;; 最初の描画から端末用の表示方法を使わせる。
  (diff-hl-margin-mode 1)
  (global-diff-hl-mode 1)

  ;; Magitの状態更新後に、開いているファイルの差分表示も更新する。
  ;; ここではMagit自体を読み込まない。
  (with-eval-after-load 'magit
    (add-hook 'magit-post-refresh-hook
              #'my/diff-hl-magit-post-refresh)
    (add-hook 'magit-post-refresh-hook
              #'my/magit-refresh-tab-line-git-status)))

;; diredに差分を表示する。
(add-hook 'dired-mode-hook #'diff-hl-dired-mode-unless-remote)


;; Emacs内で状態確認・差分確認・コミットなどを行う。
(use-package magit
  :ensure t
  :commands magit-status
  :bind ("C-x g" . my/magit-status))


;; Magitの差分をdeltaで色付けする。
(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))


;;; git.el ends here
