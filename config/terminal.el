;;; terminal.el --- Terminal configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 端末、OS、リモート環境に関する設定を置く。

;;; Code:

;; 端末の機能確認が終わってからKKPを有効にする。
(use-package kkp
  :ensure t
  :hook (tty-setup . global-kkp-mode)
  :config
  (defun my/kkp-enable-after-xterm (original &optional terminal deadline)
    "xtermの端末照会が終わってからKKPを有効にする。"
    (let* ((terminal (or terminal (frame-terminal)))
           (deadline (or deadline (time-add (current-time) 2)))
           (frame (and (terminal-live-p terminal)
                       (car (frames-on-display-list terminal)))))
      (if (and frame
               (time-less-p (current-time) deadline)
               (with-selected-frame frame
                 (functionp (lookup-key input-decode-map "\e[?"))))
          (run-with-timer
           0.02 nil
           #'my/kkp-enable-after-xterm
           original terminal deadline)
        (funcall original terminal))))

  (unless (advice-member-p #'my/kkp-enable-after-xterm
                           'kkp-enable-in-terminal)
    (advice-add 'kkp-enable-in-terminal
                :around #'my/kkp-enable-after-xterm)))

;; WezTermのJIS配列でOption+:を正しく認識する。
(with-eval-after-load 'kkp
  (defun my/kkp-jis-colon (orig input)
    "Option+:をM-:として解釈する。"
    (if (equal (concat input) "59:58:39;3u")
        (kbd "M-:")
      (funcall orig input)))

;;; terminal.el ends here
