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
  (defun my/kkp-jis-colon (orig input)
    "Option+:をM-:として解釈する。"
    (if (equal (concat input) "59:58:39;3u")
        (kbd "M-:")
      (funcall orig input)))

  (unless (advice-member-p #'my/kkp-jis-colon
                           'kkp--translate-terminal-input)
    (advice-add 'kkp--translate-terminal-input
                :around #'my/kkp-jis-colon)))


;; TRAMP先でGHCupのコマンドを見つけられるようにする。
(with-eval-after-load 'tramp
  (add-to-list 'tramp-remote-path "/root/.ghcup/bin"))


;; DockerコンテナではbashをTRAMPのリモートシェルとして使用する。
(with-eval-after-load 'tramp-container
  (let ((method (assoc "docker" tramp-methods)))
    (when method
      (let ((remote-shell (assq 'tramp-remote-shell (cdr method)))
            (direct-async (assq 'tramp-direct-async (cdr method))))
        (when remote-shell
          (setcdr remote-shell '("/bin/bash")))
        (when direct-async
          (setcdr direct-async '(("/bin/bash" "-c"))))))))


(use-package vterm
  :ensure t
  :commands vterm
  :bind ("s-j" . my/vterm-toggle))

(autoload 'my/vterm-toggle "my-vterm" nil t)


;;; terminal.el ends here
