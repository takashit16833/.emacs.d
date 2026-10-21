;;; my-org-block-colors.el --- Org block colors -*- lexical-binding: t; -*-

;;; Commentary:
;; Org 標準のブロック描画を保ちつつ、種類別に背景色と文字色を重ねる。

;;; Code:

;; テーマから配色する独自 face は、名前だけでなく face 自体の定義が必要。
;; Retro Hacker Blue 以外のテーマでは Org 標準のブロック色を継承する。
(defface my/org-block-quote
  '((t :inherit org-block))
  "引用・詩ブロックの本文。"
  :group 'org)

(defface my/org-block-quote-delimiter
  '((t :inherit org-block-begin-line))
  "引用・詩ブロックの開始・終了行。"
  :group 'org)

(defface my/org-block-comment
  '((t :inherit org-block))
  "コメントブロックの本文。"
  :group 'org)

(defface my/org-block-comment-delimiter
  '((t :inherit org-block-begin-line))
  "コメントブロックの開始・終了行。"
  :group 'org)

(defface my/org-block-export
  '((t :inherit org-block))
  "エクスポートブロックの本文。"
  :group 'org)

(defface my/org-block-export-delimiter
  '((t :inherit org-block-begin-line))
  "エクスポートブロックの開始・終了行。"
  :group 'org)

(defconst my/org-block-colors--begin-regexp
  "^[ \t]*#\\+begin_\\(quote\\|verse\\|comment\\|export\\)\\(?:[ \t].*\\)?$"
  "色分けするブロックの開始行。")

(defun my/org-block-colors--faces (kind)
  "ブロック種別 KIND に対応する本文と境界行の face を返す。"
  (cond
   ((member kind '("quote" "verse"))
    '(my/org-block-quote . my/org-block-quote-delimiter))
   ((equal kind "comment")
    '(my/org-block-comment . my/org-block-comment-delimiter))
   ((equal kind "export")
    '(my/org-block-export . my/org-block-export-delimiter))))

(defun my/org-fontify-caption-and-name (start end)
  "START から END の CAPTION と NAME をアウトラインプロパティと同じ色にする。"
  (save-excursion
    (goto-char start)
    (let ((case-fold-search t))
      (when (re-search-forward
             (rx bol (* (any " \t"))
                 (group "#+" (or "CAPTION" "NAME") ":")
                 (* (any " \t"))
                 (group (* nonl)) eol)
             end t)
        (put-text-property (match-beginning 1) (match-end 1)
                           'face 'org-special-keyword)
        (when (< (match-beginning 2) (match-end 2))
          (put-text-property (match-beginning 2) (match-end 2)
                             'face 'org-property-value))))))

(defun my/org-fontify-colored-block (limit)
  "Org 標準の色付け後、ブロックと CAPTION/NAME に独自配色を適用する。"
  (let ((start (point))
        (found (org-fontify-meta-lines-and-blocks limit))
        (case-fold-search t))
    (when found
      ;; Org 標準の処理が見つけたブロックだけを対象にする。
      ;; Font Lock が参照する元の検索結果は保持する。
      (let ((end (point)))
        (save-match-data
          (my/org-fontify-caption-and-name start end)
          (save-excursion
            (goto-char start)
            (when (re-search-forward my/org-block-colors--begin-regexp end t)
              (let* ((kind (downcase (match-string-no-properties 1)))
                     (faces (my/org-block-colors--faces kind))
                     (begin (line-beginning-position))
                     (body-begin (min (point-max) (1+ (line-end-position)))))
                (when (re-search-forward
                       (format "^[ \t]*#\\+end_%s[ \t]*$"
                               (regexp-quote kind))
                       end t)
                  (let ((body-end (line-beginning-position))
                        (finish (min (point-max) (1+ (line-end-position)))))
                    (add-face-text-property begin body-begin (cdr faces))
                    (when (< body-begin body-end)
                      (add-face-text-property body-begin body-end (car faces)))
                    (add-face-text-property body-end finish (cdr faces))))))))))
    found))

(defun my/org-block-colors-setup ()
  "Org の標準ブロック色付け処理を種類別配色つきのものに置き換える。"
  (setq org-font-lock-extra-keywords
        (mapcar
         (lambda (rule)
           (if (equal rule '(org-fontify-meta-lines-and-blocks))
               '(my/org-fontify-colored-block)
             rule))
         org-font-lock-extra-keywords)))

(with-eval-after-load 'org
  (add-hook 'org-font-lock-set-keywords-hook #'my/org-block-colors-setup))

(defun my/org-block-colors--modern-keywords (keywords)
  "org-modern のブロック色付け規則を自作処理1つにまとめる。"
  (if (member '(org-fontify-meta-lines-and-blocks) keywords)
      (mapcar (lambda (rule)
                (if (equal rule '(org-fontify-meta-lines-and-blocks))
                    '(my/org-fontify-colored-block)
                  rule))
              (remove '(my/org-fontify-colored-block) keywords))
    keywords))

(defun my/org-block-colors-setup-org-modern ()
  "org-modern が追加する標準のブロック色付けを自作処理に置き換える。"
  (when org-modern-mode
    ;; org-modern は標準の色付けを後から追加するため、先行する自作規則を
    ;; 取り除き、その位置で1回だけ実行する。ほかの装飾順序は変更しない。
    (let* ((original org-modern--font-lock-keywords)
           (updated (my/org-block-colors--modern-keywords original)))
      (unless (equal original updated)
        (font-lock-remove-keywords nil original)
        (setq-local org-modern--font-lock-keywords updated)
        (font-lock-add-keywords nil updated)))))

(with-eval-after-load 'org-modern
  (add-hook 'org-modern-mode-hook #'my/org-block-colors-setup-org-modern))

(provide 'my-org-block-colors)
;;; my-org-block-colors.el ends here
