;;; editor.el --- Editing commands -*- lexical-binding: t; -*-

;;; Commentary:
;; 行の挿入・削除・複製と選択操作をまとめる。

;;; Code:

(defun my/insert-line-below ()
  "カーソル行の下に新しい行を挿入し、その行へ移動する。"
  (interactive)
  (end-of-line)
  (newline-and-indent))


(defun my/insert-line-above ()
  "カーソル行の上に新しい行を挿入し、その行へ移動する。"
  (interactive)
  (beginning-of-line)
  (open-line 1)
  (indent-according-to-mode))


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


(defun my/select-current-line ()
  "現在行を選択する。
続けて実行すると、選択範囲を次の行まで広げる。"
  (interactive)
  (if (region-active-p)
      (goto-char (line-beginning-position 2))

    (let ((beg (line-beginning-position)))
      (goto-char (line-beginning-position 2))

      ;; Shift+カーソルによる選択と同じ一時的な選択状態にする。
      (setq-local transient-mark-mode
                  (cons 'only
                        (unless (eq transient-mark-mode 'lambda)
                          transient-mark-mode)))

      (set-mark beg)
      (activate-mark))))


(provide 'editor)
;;; editor.el ends here
