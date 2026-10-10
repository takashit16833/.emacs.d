;;; my-completion.el --- Buffer word completion -*- lexical-binding: t; -*-
;;; Commentary:
;; 既存の補完候補を優先し、バッファ内の単語を補完の後段へ追加する。

;;; Code:

(autoload 'dabbrev-capf "dabbrev")
(defun my/dabbrev-capf ()
  "単語・シンボルの直後だけdabbrevで補完する。"
  ;; 標準のdabbrev-capfは空白の直後でも「k results」などを補完できる。
  ;; コード補完では単語・シンボルだけを対象にする。
  (when (and (> (point) (point-min))
             (memq (char-syntax (char-before)) '(?w ?_)))
    (when-let* ((capf (dabbrev-capf)))
      ;; 単語補完のkindを明示し、CorfuにTextアイコンを表示させる。
      ;; Corfu側でTextの種類として表示できるようにする。
      (append capf (list :company-kind (lambda (_) 'text))))))

(defun my/dabbrev-completion-setup ()
  "既存のCAPFを優先し、dabbrevをバッファの末尾へ追加する。"
  (add-hook 'completion-at-point-functions #'my/dabbrev-capf t t))

(provide 'my-completion)
;;; my-completion.el ends here
