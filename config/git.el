;;; git.el --- Git configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Git と Magit に関する設定を置く。

;;; Code:

;; Emacs内で状態確認・差分確認・コミットなどを行う。
(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status))

;; Magitの差分をdeltaで色付けする。
(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

(provide 'git)
;;; git.el ends here
