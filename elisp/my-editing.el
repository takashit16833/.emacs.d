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

(defun my/delete-whole-line ()
  "現在の行を改行ごと削除し、空行を残さない。"
  (interactive)
  (let ((beg (line-beginning-position))
        (end (line-beginning-position 2))
	(current-column (current-column)))
    (when (and (= end (point-max))
               (> beg (point-min))
               (or (= beg end)
                   (not (eq (char-before end) ?\n))))
      (setq beg (1- beg)))
    (delete-region beg end)
    (move-to-column current-column)))

(provide 'my-editing)
;;; my-editing.el ends here
