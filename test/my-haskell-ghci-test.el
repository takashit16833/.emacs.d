;;; my-haskell-ghci-test.el --- GHCi completion tests -*- lexical-binding: t; -*-

;;; Commentary:
;; GHCiの補完応答をEmacsの候補一覧へ変換できることを確認する。

;;; Code:

(require 'ert)
(require 'my-haskell-ghci)


(ert-deftest my/haskell-ghci-parse-output-reads-prefix-and-candidates ()
  "GHCiのcomplete応答から接頭部分と候補を取り出す。"
  (with-temp-buffer
    (insert "2 2 \":m +\"\n")
    (insert "\"Rag.Database\"\n")
    (insert "\"Rag.Search\"\n")
    (should
     (equal (my/haskell-ghci-parse-output (current-buffer))
            '(":m +" "Rag.Database" "Rag.Search")))))


;;; my-haskell-ghci-test.el ends here
