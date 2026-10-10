;;; my-completion.el --- Buffer word completion -*- lexical-binding: t; -*-
;;; Commentary:
;; LSPなどの補完を変更せず、バッファ内単語の補完を後段へ追加する。

;;; Code:

;; dabbrevは候補が必要になるまで読み込まない。
(autoload 'dabbrev-capf "dabbrev")

(defun my/dabbrev-capf ()
  "単語・シンボルの直後だけdabbrevで補完する。"
  ;; 標準のdabbrev-capfは空白の直後でも、その前の単語から
  ;; 「k results」のような複数語の候補を生成するため、ここで止める。
  (when (and (> (point) (point-min))
             (memq (char-syntax (char-before)) '(?w ?_)))
    (dabbrev-capf)))

(defun my/dabbrev-completion-setup ()
  "既存のCAPFを優先し、dabbrevを現在のバッファの末尾へ追加する。"
  (add-hook 'completion-at-point-functions #'my/dabbrev-capf t t))

(provide 'my-completion)
;;; my-completion.el ends here
