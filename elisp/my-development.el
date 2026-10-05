;;; my-development.el --- Development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 開発時に使用する独自コマンドを定義する。

;;; Code:


(defun my/flymake-show-diagnostic ()
  "現在行のFlymake診断を全文表示する。"
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
      (princ
       (mapconcat #'flymake-diagnostic-text
                  diagnostics
                  "\n\n")))))


(provide 'my-development)

;;; my-development.el ends here
