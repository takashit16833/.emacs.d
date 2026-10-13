;;; my-org-table-colors-test.el --- Org table color tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Org の表で罫線・ヘッダーと通常のセルを区別できることを確認する。

;;; Code:

(require 'ert)
(require 'org)
(require 'org-table)
(require 'my-org-table-colors)

(defun my/org-table-colors-test--has-face (word wanted)
  "現在のバッファで WORD の先頭に WANTED が適用されているか確認する。"
  (save-excursion
    (goto-char (point-min))
    (when (search-forward word nil t)
      (let ((face (get-text-property
                   (- (point) (length word)) 'face)))
        (if (listp face) (memq wanted face) (eq wanted face))))))

(ert-deftest my/org-table-colors-defines-faces ()
  "装飾に使う face が定義されている。"
  (should (facep 'my/org-table-header))
  (should (facep 'my/org-table-border)))

(ert-deftest my/org-table-colors-header-borders-and-body ()
  "ヘッダー・罫線・本文をそれぞれ正しく扱う。"
  (with-temp-buffer
    (insert "| Name  | Status |\n"
            "|-------+--------|\n"
            "| Emacs | Active |\n")
    (org-mode)
    (font-lock-mode 1)
    (font-lock-ensure)
    (dolist (word '("Name" "Status"))
      (should (my/org-table-colors-test--has-face
               word 'my/org-table-header)))
    (should (my/org-table-colors-test--has-face
             "|-------+--------|" 'my/org-table-border))
    (should (my/org-table-colors-test--has-face
             "| Name" 'my/org-table-border))
    (should (my/org-table-colors-test--has-face
             "| Emacs" 'my/org-table-border))
    (should-not (my/org-table-colors-test--has-face
                 "Emacs" 'my/org-table-header))
    (should-not (my/org-table-colors-test--has-face
                 "Emacs" 'my/org-table-border))
    (should (my/org-table-colors-test--has-face "Emacs" 'org-table))))

(ert-deftest my/org-table-colors-without-separator-has-no-header ()
  "区切り線のない表は先頭行を太字扱いしない。"
  (with-temp-buffer
    (insert "| First | Row |\n| Second | Row |\n")
    (org-mode)
    (font-lock-mode 1)
    (font-lock-ensure)
    (should-not (my/org-table-colors-test--has-face
                 "First" 'my/org-table-header))
    (should (my/org-table-colors-test--has-face
             "| First" 'my/org-table-border))))

(ert-deftest my/org-table-colors-ignores-source-and-normal-text ()
  "コードブロック内と通常の文章は変更しない。"
  (with-temp-buffer
    (insert "#+begin_src text\n| This is not a table |\n#+end_src\n"
            "通常の文章です。\n")
    (org-mode)
    (font-lock-mode 1)
    (font-lock-ensure)
    (dolist (word '("| This" "This is not a table" "通常の文章です。"))
      (should-not (my/org-table-colors-test--has-face
                   word 'my/org-table-header))
      (should-not (my/org-table-colors-test--has-face
                   word 'my/org-table-border)))))

(ert-deftest my/org-table-colors-registered-in-font-lock ()
  "Org の Font Lock に独自の装飾規則が登録される。"
  (with-temp-buffer
    (org-mode)
    (should (member '(my/org-table-colors-fontify (0 nil))
                    org-font-lock-keywords))))

(provide 'my-org-table-colors-test)
;;; my-org-table-colors-test.el ends here
