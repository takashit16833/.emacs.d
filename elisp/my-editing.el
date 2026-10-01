;;; my-editing.el --- Editing commands -*- lexical-binding: t; -*-

;;; Commentary:
;; 行の挿入・削除・複製と選択操作をまとめる。

;;; Code:

(defun my/copy-region-to-clipboard (beg end)
  "選択範囲をmacOSのクリップボードへコピーする。"
  (interactive "r")
  (unless (use-region-p)
    (user-error "選択範囲がありません"))
  (unless (zerop (call-process-region beg end "pbcopy" nil nil nil))
    (user-error "クリップボードへのコピーに失敗しました"))
  (deactivate-mark)
  (message "クリップボードにコピーしました"))

(provide 'my-editing)
;;; my-editing.el ends here
