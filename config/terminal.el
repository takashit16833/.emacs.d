;;; terminal.el --- Terminal configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; 端末、OS、リモート環境に関する設定を置く。

;;; Code:

;; それぞれmwheel、tramp、my-terminalが定義する変数・関数。
;; 読み込みタイミングを変えずにコンパイラへ宣言する。
(defvar mouse-wheel-scroll-amount)
(defvar mouse-wheel-progressive-speed)
(defvar tramp-remote-path)
(declare-function my/kkp-jis-colon "my-terminal" (orig input))
(declare-function my/terminal-wheel-scroll "my-terminal" (orig event &optional arg))

;; ターミナル版Emacsでマウス操作を有効にする。
(unless (display-graphic-p)
  (xterm-mouse-mode 1)
  (mouse-wheel-mode 1)
  ;; 端末のホイールイベントは連続回数が1のため、標準の加速は使わない。
  (setq mouse-wheel-scroll-amount '(1)
        mouse-wheel-progressive-speed nil)
  ;; イベント間隔から移動量を決める。処理本体は初回スクロール時に読み込む。
  (autoload 'my/terminal-wheel-scroll "my-terminal")
  (unless (advice-member-p #'my/terminal-wheel-scroll 'mwheel-scroll)
    (advice-add 'mwheel-scroll :around #'my/terminal-wheel-scroll)))


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
