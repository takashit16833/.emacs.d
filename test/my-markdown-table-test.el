;;; my-markdown-table-test.el --- Markdown table formatter tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
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


(ert-deftest my/markdown-table-align-replaces-table-without-overlay ()
  "手動整形はテーブル用 overlay がなくても本文を書き換える。"
  ;; Tree-sitter の解析結果だけを模擬する。文字列の置換処理は実際に行う。
  (with-temp-buffer
    (insert "| 名前 | Count |\n| --- | --- |\n| A | 1 |\n")
    (let ((tick-updated nil)
          (markdown-ts-table-align-features nil))
      (cl-letf (((symbol-function 'markdown-ts--barf-if-not-mode) #'ignore)
                ((symbol-function 'markdown-ts-at-table-p)
                 (lambda (&rest _) '(t . table)))
                ((symbol-function 'treesit-node-start)
                 (lambda (_node) (point-min)))
                ((symbol-function 'treesit-node-end)
                 (lambda (_node) (point-max)))
                ((symbol-function 'treesit-search-subtree)
                 (lambda (&rest _) 'delimiter))
                ((symbol-function 'treesit-node-children)
                 (lambda (node &rest _)
                   (pcase node
                     ('table '(header delimiter body))
                     ('delimiter '(delim-left delim-right))
                     ('header '(header-left header-right))
                     ('body '(body-left body-right)))))
                ((symbol-function 'markdown-ts--table-aligners)
                 (lambda (_) '((:align unspecified)
                               (:align unspecified))))
                ((symbol-function 'treesit-node-text)
                 (lambda (node &rest _)
                   (alist-get node
                              '((header-left . "名前")
                                (header-right . "Count")
                                (delim-left . "---")
                                (delim-right . "---")
                                (body-left . "A")
                                (body-right . "1")))))
                ((symbol-function 'markdown-ts--table-tick-update)
                 (lambda (_pos) (setq tick-updated t))))
        (my/markdown-table-align)
        (should tick-updated)
        (should (equal (buffer-string)
                       "|名前|Count|\n|----|-----|\n|A   |1    |\n"))))))

(provide 'my-markdown-table-test)
;;; my-markdown-table-test.el ends here
