;;; git.el --- Git configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Git と Magit に関する設定を置く。

;;; Code:

(require 'my-tab-context)
(require 'my-tab-line)

;; Magitの更新後に呼び出す独自処理は必要になるまで読み込まない。
(autoload 'my/magit-refresh-tab-line-git-status "my-git")
(autoload 'my/diff-hl-magit-post-refresh "my-git")


;; 編集中のファイルにGitとの差分を表示する。
(use-package diff-hl
  :ensure t
  :defer 0.5

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
  ;; ignoredの「i」は余白に表示せず、Dirvish側でファイル名を暗くする。
  (setopt diff-hl-margin-symbols-alist
          '((insert . "│")
            (change . "│")
            (delete . "│")
            (unknown . "?")
            (ignored . " ")
            (reference . " ")))

  ;; global-diff-hl-modeを有効にする前にmargin表示へ切り替える。
  ;; 最初の描画から端末用の表示方法を使わせる。
  (diff-hl-margin-mode 1)
  (global-diff-hl-mode 1)
  
  ;; diredに差分を表示する。
  (add-hook 'dired-mode-hook #'diff-hl-dired-mode-unless-remote)

  ;; Magitの状態更新後に、開いているファイルの差分表示も更新する。
  ;; ここではMagit自体を読み込まない。
  (with-eval-after-load 'magit
    (add-hook 'magit-post-refresh-hook
              #'my/diff-hl-magit-post-refresh)
    (add-hook 'magit-post-refresh-hook
              #'my/magit-refresh-tab-line-git-status)))


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
