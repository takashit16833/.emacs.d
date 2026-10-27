;;; my-markdown-table.el --- Display-width aware table alignment -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs 31.1's markdown-ts table aligner counts characters rather than
;; terminal columns.  Keep its Tree-sitter table parsing and replacement
;; behavior while measuring CJK cells with `string-width'.

;;; Code:

(require 'cl-lib)
(require 'markdown-ts-mode)
(require 'subr-x)

(defun my/markdown-table--pad (text width align)
  "Pad TEXT to WIDTH terminal columns according to ALIGN."
  (let* ((pad (max 0 (- width (string-width text))))
         (left (pcase align
                 ('right pad)
                 ('center (/ pad 2))
                 (_ 0))))
    (concat (make-string left ?\s)
            text
            (make-string (- pad left) ?\s))))

(defun my/markdown-table--align (align-cells automatic)
  "Align the current table by display width.
For AUTOMATIC alignment, skip tables without pending changes."
  (markdown-ts--barf-if-not-mode 'my/markdown-table-align)
  (when-let* ((at-table (markdown-ts-at-table-p nil t))
              (table (cdr at-table))
              (beg (treesit-node-start table))
              (end (treesit-node-end table))
              (_ (or (not automatic)
                     (markdown-ts--table-tick-stale-p beg)))
              (rows (treesit-node-children table 'named))
              (delimiter (treesit-search-subtree
                          table "\\`pipe_table_delimiter_row\\'"))
              (aligners (markdown-ts--table-aligners table))
              (ncols (length (treesit-node-children delimiter 'named))))
    ;; nil は when-let* の失敗条件になるため、作業用変数は let で初期化する。
    (let ((widths (make-vector ncols 3))
          (contents nil))
      (setq align-cells (or align-cells current-prefix-arg
                            (memq 'justify-cells markdown-ts-table-align-features)))
      (without-restriction
        (cl-loop for row in rows for index from 0 do
                 (let ((cells (treesit-node-children row 'named))
                       (values nil))
                   (dotimes (col ncols)
                     (let ((value (if-let* ((cell (nth col cells)))
                                      (string-trim-right (treesit-node-text cell t))
                                    "")))
                       (push value values)
                       (unless (= index 1)
                         (aset widths col
                               (max (aref widths col) (string-width value))))))
                   (push (nreverse values) contents)))
        (setq contents (nreverse contents))
        (let ((source (current-buffer)))
          (with-temp-buffer
            (cl-loop for values in contents for index from 0 do
                     (dotimes (col ncols)
                       (let* ((width (aref widths col))
                              (align (or (plist-get (nth col aligners) :align)
                                         'unspecified))
                              (value (nth col values)))
                         (insert "|"
                                 (if (= index 1)
                                     (markdown-ts--table-make-aligner width align)
                                   (my/markdown-table--pad
                                    value width
                                    (if align-cells align 'unspecified))))))
                     (insert "|\n"))
            (let ((replacement (current-buffer)))
              (with-current-buffer source
                (replace-region-contents beg end replacement))))))
      (markdown-ts--table-tick-update beg))))

(defun my/markdown-table-align (&optional align-cells)
  "Align the Markdown table at point using terminal display widths.
With prefix ALIGN-CELLS, honor the delimiter row's cell alignment."
  (interactive "P")
  (my/markdown-table--align align-cells nil))

(defun my/markdown-table--auto-align (&optional align-cells)
  "Align automatically, only when the table has changed."
  (my/markdown-table--align align-cells t))

(defun my/markdown-table-setup ()
  "Use display widths for manual and automatic Markdown table alignment."
  ;; 表内の minor mode のキー設定は major mode より優先される。
  (keymap-set markdown-ts-in-table-mode-map
              "C-c C-c" #'my/markdown-table-align)
  ;; TAB 移動などの標準の自動整形も同じ処理を使う。
  ;; 自動整形の変更検知は --auto-align 側で維持する。
  (unless (advice-member-p #'my/markdown-table--auto-align
                           'markdown-ts-table-align-table)
    (advice-add 'markdown-ts-table-align-table
                :override #'my/markdown-table--auto-align)))


;; 表のセルは markdown-inline 解析の対象外なので、装飾だけを補う。
;; マークアップを隠すと表の列幅が変わるため、文字は一切変更しない。
(defconst my-markdown-table--inline-regexp
  "`[^`\n]+`\\|\\*\\*[^*\n]+\\*\\*\\|\\*[^*\n]+\\*"
  "Simple code, bold and italic markup in Markdown table cells.")

(defun my-markdown-table--fontify-cell (node override start end &rest _)
  "Fontify inline markup inside table cell NODE without changing its width.
OVERRIDE, START and END are provided by Tree-sitter font lock."
  (let ((cell-start (treesit-node-start node))
        (cell-end (treesit-node-end node)))
    (save-excursion
      (goto-char cell-start)
      (while (re-search-forward my-markdown-table--inline-regexp cell-end t)
        (let* ((beg (match-beginning 0))
               (finish (match-end 0))
               (code (eq (char-after beg) ?`))
               (bold (and (not code) (eq (char-after (1+ beg)) ?*)))
               (marker-width (if code 0 (if bold 2 1))))
          ;; エスケープされた開始記号は装飾しない。
          (unless (and (> beg cell-start) (eq (char-before beg) ?\\))
            (treesit-fontify-with-override
             (+ beg marker-width) (- finish marker-width)
             (cond (code 'markdown-ts-code-span)
                   (bold 'markdown-ts-bold)
                   (t 'markdown-ts-emphasis))
             override start end)))))))

(defun my-markdown-table-fontify-setup ()
  "Enable inline emphasis and code faces inside Markdown table cells."
  (treesit-add-font-lock-rules
   (treesit-font-lock-rules
    :language 'markdown
    :feature 'paragraph-inline
    :override 'prepend
    '((pipe_table_cell) @my-markdown-table--fontify-cell))))

(provide 'my-markdown-table)
;;; my-markdown-table.el ends here
