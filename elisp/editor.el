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


(defun my/delete-to-line-beginning ()
  "カーソル位置から行頭までを削除する。"
  (interactive)
  (delete-region (line-beginning-position) (point)))


(defun my/delete-to-line-end ()
  "カーソル位置から行末までを削除する。"
  (interactive)
  (delete-region (point) (line-end-position)))


(defun my/delete-word-forward (arg)
  "カーソルから前方の単語を削除する。"
  (interactive "p")
  (delete-region
   (point)
   (save-excursion
     (forward-word arg)
     (point))))


(defun my/delete-word-backward (arg)
  "カーソルから後方の単語を削除する。"
  (interactive "p")
  (delete-region
   (point)
   (save-excursion
     (backward-word arg)
     (point))))


(defun my/select-to-line-beginning ()
  "カーソル位置から行頭まで一時的に選択する。"
  (interactive)
  (setq this-command-keys-shift-translated t)
  (call-interactively #'move-beginning-of-line))


(defun my/select-to-line-end ()
  "カーソル位置から行末まで一時的に選択する。"
  (interactive)
  (setq this-command-keys-shift-translated t)
  (call-interactively #'move-end-of-line))


(defun my/clear-undo-history ()
  "現在のバッファのUndo・Redo履歴を消去する。"
  (interactive)
  (setq buffer-undo-list nil
	pending-undo-list nil)
  (message "Undo履歴を消去しました"))


(defun my/clear-undo-history-all ()
  "Undoが有効なすべてのバッファのUndo・Redo履歴を消去する。"
  (interactive)
  (let ((count 0))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
	(unless (eq buffer-undo-list t)
	  (setq buffer-undo-list nil
		count (1+ count)))))
    (setq pending-undo-list nil)
    (message "%d個のバッファのUndo履歴を削除しました" count)))


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
