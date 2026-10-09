;;; my-vterm.el --- vterm utilities -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 現在のタブのディレクトリに対応するvtermを管理する。

;;; Code:

(require 'my-tab-context)

(declare-function vterm "vterm" (&optional arg))

(defvar vterm-buffer-name)
(defvar project-current-directory-override)


(defun my/vterm--buffer-name (directory)
  "DIRECTORYに対応するvtermバッファ名を返す。"
  (format "*vterm:%s*"
          (abbreviate-file-name
           (directory-file-name directory))))


(defun my/vterm-toggle ()
  "現在の文脈に対応するvtermを表示・非表示する。"
  (interactive)
  (let* ((directory
          (or project-current-directory-override
              (my/tab-context-directory)
              default-directory))
         (buffer-name (my/vterm--buffer-name directory))
         (buffer (get-buffer buffer-name))
         (window (and buffer (get-buffer-window buffer))))
    (if window
        (with-selected-window window
	  (previous-buffer))
      (let ((default-directory directory)
            (vterm-buffer-name buffer-name))
        (vterm)))))


(provide 'my-vterm)

;;; my-vterm.el ends here
