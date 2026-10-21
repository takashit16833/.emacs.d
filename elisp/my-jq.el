;;; my-jq.el --- jq Playground -*- lexical-binding: t; -*-

;;; Commentary:
;; 選択したJSONを再利用可能なjq確認用バッファで開く。

;;; Code:

(declare-function jq-interactively "jq-mode" ())
(declare-function js-json-mode "js" ())


(defun my/jq-playground ()
  "jqの式を試すためのJSONバッファを開く。
選択範囲があれば、その文字列でPlaygroundの内容を置き換える。
選択範囲がなければ既存の内容を維持する。
JSONを編集したらC-c C-jで \`jq-interactively' を起動する。"
  (interactive)
  (let* ((text (when (use-region-p)
                 (buffer-substring-no-properties
                  (region-beginning) (region-end))))
         (name "*jq-playground*")
         (existing (get-buffer name))
         (buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (unless existing
        (js-json-mode)
        (insert "[]\n")
        ;; 通常のJSONバッファへ影響しないよう、専用のキーマップを使う。
        (let ((map (copy-keymap (current-local-map))))
          (keymap-set map "C-c C-j" #'jq-interactively)
          (use-local-map map)))
      (when text
        (erase-buffer)
        (insert text)))
    (switch-to-buffer buffer)))


(provide 'my-jq)

;;; my-jq.el ends here
