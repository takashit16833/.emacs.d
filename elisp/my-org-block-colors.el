;;; my-org-block-colors.el --- Org block colors -*- lexical-binding: t; -*-
;;; Commentary:
;; Org 標準のブロック描画を保ちつつ、種類別に背景色と文字色を重ねる。

;;; Code:

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

(defun my/org-fontify-colored-block (limit)
  "Org 標準の色付け後、LIMIT 内の対象ブロックに種類別の色を付ける。"
  (let ((start (point))
        (found (org-fontify-meta-lines-and-blocks limit)))
    (when found
      ;; Org 標準の処理が見つけたブロックだけを対象にする。
      ;; Font Lock が参照する元の検索結果は保持する。
      (let ((end (point)))
        (save-match-data
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

(provide 'my-org-block-colors)
;;; my-org-block-colors.el ends here
