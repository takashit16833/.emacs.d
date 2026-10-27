;;; my-markdown-table-test.el --- Markdown table formatter tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'my-markdown-table)

(ert-deftest my/markdown-table-pad-japanese ()
  (should (equal (my/markdown-table--pad "日本語" 8 'left) "日本語  "))
  (should (equal (my/markdown-table--pad "日本語" 8 'right) "  日本語"))
  (should (equal (my/markdown-table--pad "日本語" 9 'center) " 日本語  ")))

(ert-deftest my/markdown-table-pad-mixed ()
  (let ((value (my/markdown-table--pad "AWSへのデプロイ" 24 'left)))
    (should (= (string-width value) 24))
    (should (string-prefix-p "AWSへのデプロイ" value))))

(ert-deftest my/markdown-table-pad-never-truncates ()
  (should (equal (my/markdown-table--pad "日本語" 3 'left) "日本語")))

(provide 'my-markdown-table-test)
;;; my-markdown-table-test.el ends here
