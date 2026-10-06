;;; my-development.el --- Development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 開発時に使用する独自コマンドを定義する。

;;; Code:


(defun my/flymake-diagnostic-type-label (diagnostic)
  "DIAGNOSTICの種類を色付きの表示用文字列にする。"
  (pcase (flymake-diagnostic-type diagnostic)
    (:error
     (propertize "[ERROR]" 'face 'flymake-error-echo))
    (:warning
     (propertize "[WARNING]" 'face 'flymake-warning-echo))
    (:note
     (propertize "[NOTE]" 'face 'flymake-note-echo))
    (type
     (format "[%s]" type))))


(defun my/flymake-format-diagnostic (diagnostic)
  "DIAGNOSTICを表示用文字列にする。"
  (concat
   (my/flymake-diagnostic-type-label diagnostic)
   " "
   (flymake-diagnostic-text diagnostic)))


(defun my/flymake-show-diagnostic ()
  "現在行のFlymake診断を種類付きで全文表示する。"
  (interactive)
  (require 'flymake)
  (let ((diagnostics
         (flymake-diagnostics
          (line-beginning-position)
          (line-end-position)))
        (help-window-select t))
    (unless diagnostics
      (user-error "この行に診断はありません"))
    (with-help-window "*Flymake diagnostic*"
      (with-current-buffer standard-output
        (insert
         (mapconcat #'my/flymake-format-diagnostic
                    diagnostics
                    "\n\n"))))))


(provide 'my-development)

;;; my-development.el ends here
