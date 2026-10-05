;;; git.el --- Git configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Git と Magit に関する設定を置く。

;;; Code:

(require 'my-tab-context)


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
