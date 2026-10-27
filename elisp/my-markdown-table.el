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

(defun my/markdown-table-align (&optional align-cells)
  "Align the Markdown table at point using terminal display widths.
With prefix ALIGN-CELLS, honor the delimiter row's cell alignment."
  (interactive "P")
  (markdown-ts--barf-if-not-mode 'my/markdown-table-align)
  (when-let* ((at-table (markdown-ts-at-table-p nil t))
              (table (cdr at-table))
              (beg (treesit-node-start table))
              (end (treesit-node-end table))
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

(provide 'my-markdown-table)
;;; my-markdown-table.el ends here
