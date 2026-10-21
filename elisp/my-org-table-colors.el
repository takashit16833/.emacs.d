;;; my-org-table-colors.el --- Org table colors -*- lexical-binding: t; -*-

;;; Commentary:
;; テーブルの本文色を維持し、ヘッダーと罫線だけを個別の face で表示する。

;;; Code:

(defface my/org-table-header
  '((t :inherit org-table :weight bold))
  "Org テーブルのヘッダーに使う face。"
  :group 'org)

(defface my/org-table-border
  '((t :inherit org-table :weight normal))
  "Org テーブルの縦横罫線に使う face。"
  :group 'org)

(defun my/org-table-colors-fontify (limit)
  "LIMIT までのテーブル行を探し、ヘッダーと罫線を色分けする。"
  (when (re-search-forward "^[ \t]*|[^\n]*$" limit t)
    (let ((begin (match-beginning 0))
          (end (match-end 0)))
      (save-match-data
        (save-excursion
          (goto-char begin)
          ;; コードブロック内の「|」で始まる行には適用しない。
          (when (org-at-table-p)
            (if (looking-at-p org-table-hline-regexp)
                ;; 横罫線は行全体を同じ色にする。
                (add-face-text-property begin end 'my/org-table-border)
              ;; 直後が区切り線なら、この行がヘッダー。
              (when (save-excursion
                      (forward-line 1)
                      (looking-at-p org-table-hline-regexp))
                (add-face-text-property begin end 'my/org-table-header))
              ;; 本文の文字色は維持し、縦罫線だけ色を上書きする。
              (while (search-forward "|" end t)
                (add-face-text-property (1- (point)) (point)
                                        'my/org-table-border))))))
      t)))

(defun my/org-table-colors-setup ()
  "Org の標準 Font Lock 規則の後に表の装飾を追加する。"
  (setq org-font-lock-extra-keywords
        (append org-font-lock-extra-keywords
                '((my/org-table-colors-fontify (0 nil))))))

(with-eval-after-load 'org
  (add-hook 'org-font-lock-set-keywords-hook #'my/org-table-colors-setup))

(provide 'my-org-table-colors)
;;; my-org-table-colors.el ends here
