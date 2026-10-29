;;; my-terminal.el --- Terminal input helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 端末のキー入力を補正する独自処理。

;;; Code:

(defun my/kkp-jis-colon (orig input)
  "Option+:をM-:として解釈する。"
  (if (equal (concat input) "59:58:39;3u")
      (kbd "M-:")
    (funcall orig input)))

(provide 'my-terminal)

;;; my-terminal.el ends here
