;;; terminal.el --- Terminal configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 端末、OS、リモート環境に関する設定を置く。

;;; Code:

;; 端末でKitty Keyboard Protocolを有効にする。
(use-package kkp
  :ensure t
  :hook (tty-setup . global-kkp-mode))


;; WezTermのJIS配列でOption+:を正しく認識する。
(with-eval-after-load 'kkp
  (defun my/kkp-jis-colon (orig input)
    "Option+:をM-:として解釈する。"
    (if (equal (concat input) "59:58:39;3u")
        (kbd "M-:")
      (funcall orig input)))

  (unless (advice-member-p #'my/kkp-jis-colon
                           'kkp--translate-terminal-input)
    (advice-add 'kkp--translate-terminal-input
                :around #'my/kkp-jis-colon)))


(use-package vterm
  :ensure t
  :commands vterm
  :bind ("s-j" . my/vterm-toggle))

(autoload 'my/vterm-toggle "my-vterm" nil t)


;;; terminal.el ends here
