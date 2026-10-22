;;; terminal.el --- Terminal configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; 端末、OS、リモート環境に関する設定を置く。

;;; Code:

;; ターミナル版Emacsでマウス操作を有効にする。
(unless (display-graphic-p)
  (xterm-mouse-mode 1)
  (mouse-wheel-mode 1)
  ;; 1ノッチで2行動かす。
  (setq mouse-wheel-scroll-amount '(2)))


;; 端末でKitty Keyboard Protocolを有効にする。
(use-package kkp
  :ensure t
  :hook (tty-setup . global-kkp-mode))


;; WezTermのJIS配列でOption+:を正しく認識する。
(with-eval-after-load 'kkp
  (autoload 'my/kkp-jis-colon "my-terminal")

  (unless (advice-member-p #'my/kkp-jis-colon
                           'kkp--translate-terminal-input)
    (advice-add 'kkp--translate-terminal-input
                :around #'my/kkp-jis-colon)))


;; TRAMP先でGHCupのコマンドを見つけられるようにする。
(with-eval-after-load 'tramp
  (add-to-list 'tramp-remote-path "/root/.ghcup/bin"))


(use-package vterm
  :ensure t
  :commands vterm
  :custom
  ;; DockerのTRAMP先ではbashを使用する。
  (vterm-tramp-shells
   '(("ssh" login-shell)
     ("scp" login-shell)
     ("docker" "/bin/bash")))
  :bind ("s-j" . my/vterm-toggle))

(autoload 'my/vterm-toggle "my-vterm" nil t)


;;; terminal.el ends here
