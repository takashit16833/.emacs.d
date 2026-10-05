;;; my-vterm.el --- vterm utilities -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 現在のタブのディレクトリに対応するvtermを管理する。
;;
;; `my/vterm-toggle' で、
;;
;; - vtermが表示されていなければ開く
;; - 表示されていれば閉じる
;;
;; ディレクトリごとにvtermバッファを分ける。

;;; Code:

(declare-function my/tab-context-directory "my-tab-context")
(declare-function vterm "vterm" (&optional arg))

(defvar vterm-buffer-name)


(defun my/vterm--directory ()
  "現在のタブでvtermを開くディレクトリを返す。"
  (or (my/tab-context-directory)
      default-directory))


(defun my/vterm--buffer-name (directory)
  "DIRECTORYに対応するvtermバッファ名を返す。"
  (format "*vterm:%s*"
          (abbreviate-file-name
           (directory-file-name directory))))


(defun my/vterm-toggle ()
  "現在のタブのディレクトリに対応するvtermを表示・非表示する。"
  (interactive)
  (let* ((directory (my/vterm--directory))
         (buffer-name (my/vterm--buffer-name directory))
         (buffer (get-buffer buffer-name))
         (window (and buffer (get-buffer-window buffer))))
    (if window
        ;; vtermが表示されている場合は閉じる。
        (if (one-window-p t)
            (with-selected-window window
              (previous-buffer))
          (delete-window window))

      ;; vtermが表示されていなければ開く。
      (let ((default-directory directory)
            (vterm-buffer-name buffer-name))
        (vterm)))))


(provide 'my-vterm)

;;; my-vterm.el ends here
