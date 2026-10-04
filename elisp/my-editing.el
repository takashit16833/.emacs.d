;;; my-editing.el --- Editing commands -*- lexical-binding: t; -*-

;;; Commentary:
;; 行の挿入・削除・複製と選択操作をまとめる。

;;; Code:


;; ペースト時に選択範囲を上書きする。
(delete-selection-mode 1)
(with-eval-after-load 'term/xterm
  (put 'xterm-paste 'delete-selection 'yank))


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


(defun my/smart-beginning-of-line ()
  "カーソル位置を文頭・行頭でトグルする。"
  (interactive "^")
  (let ((indentation-position
	 (save-excursion
	   (back-to-indentation)
	   (point))))
    (if (not (= indentation-position (point)))
	(back-to-indentation)
      (beginning-of-line))))


(defun my/select-to-line-beginning ()
  "カーソル位置から行頭まで一時的に選択する。"
  (interactive)
  (setq this-command-keys-shift-translated t)
  (call-interactively #'my/smart-beginning-of-line))


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


(defun my/paste-from-clipboard ()
  "macOSのクリップボードから貼り付ける。"
  (interactive)
  (let ((text
         (with-temp-buffer
           (call-process "pbpaste" nil t nil)
           (buffer-string))))
    (insert-for-yank text)))

;; 選択中に貼り付けた場合は、選択範囲を貼り付け内容で置き換える。
(put 'my/paste-from-clipboard 'delete-selection 'yank)


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


(defun my/line-block-bounds ()
  "現在行、または選択範囲を含む行全体の範囲を返す。"
  (if (use-region-p)
      (let ((begin (region-beginning))
	    (end (region-end)))
	(cons
	 (save-excursion
	   (goto-char begin)
	   (line-beginning-position))
	 (save-excursion
	   (goto-char end)
	   ;; 選択範囲の末尾が行頭の場合、その行は含めない。
	   (if (and (bolp) (> end begin))
	       end
	     (line-beginning-position 2)))))
    (cons
     (line-beginning-position)
     (line-beginning-position 2))))


(defun my/duplicate-lines (direction)
  "現在行または選択した行をDIRECTION方向へ複製する。"
  (let* (;; コピーテキストを準備する。
	 (bounds (my/line-block-bounds))
	 (begin (car bounds))
	 (end (cdr bounds))
	 (text (buffer-substring begin end))
	 ;; 現在の情報を取得する。
	 (region-active-p (use-region-p))
	 (original-point (point))
	 (original-mark (and region-active-p (mark)))
	 (point-offset (- original-point begin))
         (mark-offset
          (and region-active-p
               (- original-mark begin)))
	 ;; 末尾行に改行があるか調べる。
	 (ends-with-newline-p
          (and (> end begin)
               (eq (char-before end) ?\n)))
	 copy-begin)
    
    ;; 編集によって選択が解除されないようにする。
    (let (deactivate-mark)
      ;; 異常終了した場合、この中で行ったバッファ変更を取り消す。
      (atomic-change-group
	(pcase direction
	  ('down
	   (goto-char end)

	   ;; 末尾行に改行がない状態で、そのまま文字列を挿入すると
	   ;; 「次の行」にならず、同じ行に連結されてしまう
	   (unless ends-with-newline-p
	     (insert "\n"))

	   ;; コピー開始位置を記憶する。
	   (setq copy-begin (point))

	   ;; コピーしたいテキストを挿入する。
	   (insert text))
	  ('up
	   (goto-char begin)
	   
	   ;; コピー開始位置を記憶する。
	   (setq copy-begin (point))
	   
	   ;; コピーしたいテキストを挿入する。
	   (insert text)
	   
	   ;; 末尾行に改行がない状態で、そのまま文字列を挿入すると
	   ;; 「次の行」にならず、同じ行に連結されてしまう
	   (unless ends-with-newline-p
	     (insert "\n"))))

	;; 複製した側でも、元と同じ相対位置へカーソルを移動する。
	(goto-char (+ copy-begin point-offset))

	;; 複製した側でも、元と同じ相対位置にmarkを設定する。
	(when region-active-p
	  (set-mark (+ copy-begin mark-offset)))))))


(defun my/duplicate-lines-up ()
  "現在行または選択した行を上へ複製する。"
  (interactive)
  (my/duplicate-lines 'up))


(defun my/duplicate-lines-down ()
  "現在行または選択した行を下へ複製する。"
  (interactive)
  (my/duplicate-lines 'down))


(provide 'my-editing)
;;; my-editing.el ends here
