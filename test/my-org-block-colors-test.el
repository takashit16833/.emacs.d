;;; my-org-block-colors-test.el --- Org block color tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Org 標準の Font Lock と組み合わせたブロックの配色を確認する。

;;; Code:

(require 'ert)
(require 'org)
(require 'my-org-block-colors)

(defun my/org-block-colors-test--has-face (word expected)
  "WORD の先頭文字の face に EXPECTED が含まれているか判定する。"
  (save-excursion
    (goto-char (point-min))
    (when (search-forward word nil t)
      (let ((face (get-text-property (- (point) (length word)) 'face)))
        (if (listp face)
            (memq expected face)
          (eq face expected))))))

(ert-deftest my/org-block-colors-fontifies-whole-blocks ()
  "開始行、本文、終了行のすべてに専用 face を付ける。"
  (with-temp-buffer
    (insert "#+begin_quote\n引用です。\n#+end_quote\n"
            "#+begin_verse\n詩です。\n#+end_verse\n"
            "#+begin_comment\nコメントです。\n#+end_comment\n"
            "#+begin_export html\nExport text\n#+end_export\n")
    (org-mode)
    (font-lock-ensure)
    (dolist (case '(("quote" "引用です。" my/org-block-quote
                     my/org-block-quote-delimiter)
                    ("verse" "詩です。" my/org-block-quote
                     my/org-block-quote-delimiter)
                    ("comment" "コメントです。" my/org-block-comment
                     my/org-block-comment-delimiter)
                    ("export" "Export text" my/org-block-export
                     my/org-block-export-delimiter)))
      (let ((kind (nth 0 case))
            (body (nth 1 case))
            (body-face (nth 2 case))
            (edge-face (nth 3 case)))
        (should (my/org-block-colors-test--has-face
                 (concat "#+begin_" kind) edge-face))
        (should (my/org-block-colors-test--has-face body body-face))
        (should (my/org-block-colors-test--has-face
                 (concat "#+end_" kind) edge-face))))))

(ert-deftest my/org-block-colors-preserves-source-and-other-text ()
  "src/example と通常の本文を種類別配色の対象にしない。"
  (with-temp-buffer
    (insert "#+begin_src emacs-lisp\n(message \"Hello\")\n#+end_src\n"
            "#+begin_example\nExample text\n#+end_example\n"
            "通常の本文です。\n")
    (org-mode)
    (font-lock-ensure)
    (dolist (word '("#+begin_src" "message" "#+end_src"
                    "#+begin_example" "Example text" "#+end_example"
                    "通常の本文です。"))
      (dolist (face '(my/org-block-quote my/org-block-comment
                      my/org-block-export
                      my/org-block-quote-delimiter
                      my/org-block-comment-delimiter
                      my/org-block-export-delimiter))
        (should-not (my/org-block-colors-test--has-face word face))))))

(ert-deftest my/org-block-colors-registered-in-org-keywords ()
  "元の Org ブロック色付け規則が二重実行されない。"
  (with-temp-buffer
    (org-mode)
    (should (member '(my/org-fontify-colored-block)
                    org-font-lock-keywords))
    (should-not (member '(org-fontify-meta-lines-and-blocks)
                        org-font-lock-keywords))))

(provide 'my-org-block-colors-test)
;;; my-org-block-colors-test.el ends here
