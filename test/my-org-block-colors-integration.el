;;; my-org-block-colors-integration.el --- Org Modern block color integration -*- lexical-binding: t; -*-

;;; Commentary:
;; org-modern 有効時の Org ブロック配色を実際のパッケージと組み合わせて確認する。
;; test/run-all-tests.sh が package-initialize 後にこのファイルを読み込む。

;;; Code:

(require 'ert)
(require 'org)
(require 'my-org-block-colors)
(require 'org-modern)

(ert-deftest my/org-block-colors-org-modern-fontifies-delimiters ()
  "org-modern を有効にしても引用・コメントの開始・終了行を色分けする。"
  (with-temp-buffer
    (insert "#+begin_quote\n引用文\n#+end_quote\n"
            "#+begin_comment\nコメント文\n#+end_comment\n"
            "#+begin_export html\nExport text\n#+end_export\n")
    (org-mode)
    (org-modern-mode 1)
    (font-lock-mode 1)
    (font-lock-ensure)
    (should-not (member '(org-fontify-meta-lines-and-blocks)
                        org-modern--font-lock-keywords))
    (should (= 1
               (length (seq-filter
                        (lambda (rule)
                          (equal rule '(my/org-fontify-colored-block)))
                        org-modern--font-lock-keywords))))
    (dolist (case '(("quote" "引用文" my/org-block-quote
                     my/org-block-quote-delimiter)
                    ("comment" "コメント文" my/org-block-comment
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

(provide 'my-org-block-colors-integration)
;;; my-org-block-colors-integration.el ends here
