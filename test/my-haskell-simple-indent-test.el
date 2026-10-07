;;; my-haskell-simple-indent-test.el --- Tests for simple Haskell indentation -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-haskell-simple-indent' のテスト。

;;; Code:

(require 'ert)
(require 'my-haskell-simple-indent)

(ert-deftest my/haskell-simple-indent-increases-after-vscode-triggers ()
  "VS Code と同じ主要な行末では次行を1段深くすること。"
  (dolist (text '("foo ="
                  "foo ->"
                  "foo >>="
                  "foo >=>"
                  "foo =<<"
                  "then"
                  "else"
                  "do"
                  "mdo"
                  "of"
                  "let"
                  "in"
                  "where"
                  "if ready"
                  "data Foo"))
    (should (my-haskell-simple-indent--increase-p text))))

(ert-deftest my/haskell-simple-indent-does-not-match-identifiers ()
  "キーワードを含むだけの識別子ではインデントを増やさないこと。"
  (dolist (text '("doSomething"
                  "somewhere"
                  "metadata Foo"
                  "if ready then pure ()"
                  "putStrLn value"))
    (should-not (my-haskell-simple-indent--increase-p text))))

(ert-deftest my/haskell-simple-indent-user-do-example ()
  "case の分岐末尾が do のとき期待する6列目へ移動すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (insert "  case queryEmbedding of\n"
            "    Nothing ->\n"
            "      putStrLn \"Failed to decode query embedding.\"\n"
            "    Just queryVector -> do\n")
    (my-haskell-simple-indent-line)
    (should (= (current-indentation) 6))
    (should (= (current-column) 6))))

(ert-deftest my/haskell-simple-indent-tab-corrects-current-indent ()
  "空行上のTABは indent-relative ではなく Haskell 用の位置へ移動すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (my-haskell-simple-indent-setup)
    (insert "    Just queryVector -> do\n    ")
    (indent-for-tab-command)
    (should (= (current-indentation) 6))
    (should (= (current-column) 6))))

(ert-deftest my/haskell-simple-indent-inherits-after-ordinary-line ()
  "通常行の次は直前行と同じ深さを維持すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (insert "      putStrLn value\n")
    (my-haskell-simple-indent-line)
    (should (= (current-indentation) 6))))

(ert-deftest my/haskell-simple-indent-skips-blank-line ()
  "空行を挟んでも直近のコード行と同じ深さを維持すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (insert "    Just queryVector -> do\n"
            "      topChunks <- searchChunks queryVector\n"
            "\n")
    (my-haskell-simple-indent-line)
    (should (= (current-indentation) 6))
    (should (= (current-column) 6))))

(ert-deftest my/haskell-simple-indent-tab-skips-blank-line ()
  "空行の次でもTAB一発で直近のコード行の深さへ移動すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (my-haskell-simple-indent-setup)
    (insert "    Just queryVector -> do\n"
            "      topChunks <- searchChunks queryVector\n"
            "\n")
    (indent-for-tab-command)
    (should (= (current-indentation) 6))
    (should (= (current-column) 6))))

(ert-deftest my/haskell-simple-indent-preserves-existing-code ()
  "既存コードのインデントは軽量規則で推測して変更しないこと。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (insert "      putStrLn value\n"
            "    Just other -> do")
    (my-haskell-simple-indent-line)
    (should (= (current-indentation) 4))))

(ert-deftest my/haskell-simple-indent-setup-prevents-previous-line-reindent ()
  "RET時には直前行を再インデントしない設定にすること。"
  (with-temp-buffer
    (my-haskell-simple-indent-setup)
    (should (eq indent-line-function #'my-haskell-simple-indent-line))
    (should electric-indent-inhibit)))

;;; my-haskell-simple-indent-test.el ends here
