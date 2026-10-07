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

(ert-deftest my/haskell-simple-indent-next-column-case-do ()
  "case 分岐の do は1段深くすること。"
  (setq-local my-haskell-simple-indent-offset 2)
  (should (= (my-haskell-simple-indent--next-column
              "    Just queryVector -> do" 4)
             6)))

(ert-deftest my/haskell-simple-indent-next-column-lambda-do ()
  "lambda の -> do は lambda 本体と do 本体の2段を開くこと。"
  (setq-local my-haskell-simple-indent-offset 2)
  (should (= (my-haskell-simple-indent--next-column
              "        ( \\(chunk, score) -> do" 8)
             12)))

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

(ert-deftest my/haskell-simple-indent-preserves-existing-code ()
  "既存コードのインデントは軽量規則で推測して変更しないこと。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (insert "      putStrLn value\n"
            "    Just other -> do")
    (my-haskell-simple-indent-line)
    (should (= (current-indentation) 4))))

(ert-deftest my/haskell-simple-indent-setup-binds-entry-commands ()
  "setup は RET と TAB を軽量インデント用コマンドへ接続すること。"
  (with-temp-buffer
    (my-haskell-simple-indent-setup)
    (should (eq (key-binding (kbd "RET"))
                #'my-haskell-simple-indent-newline))
    (should (eq (key-binding (kbd "TAB"))
                #'my-haskell-simple-indent-tab))
    (should (eq (key-binding (kbd "<tab>"))
                #'my-haskell-simple-indent-tab))))

(ert-deftest my/haskell-simple-indent-ret-lambda-do-workflow ()
  "lambda の -> do 末尾で RET 一発で12列目へ移動すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (my-haskell-simple-indent-setup)
    (insert "      mapM_\n"
            "        ( \\(chunk, score) -> do")
    (call-interactively (key-binding (kbd "RET")))
    (should (= (current-indentation) 12))
    (should (= (current-column) 12))))

(ert-deftest my/haskell-simple-indent-ret-then-tab-workflow ()
  "曖昧な単独行では RET は深さを維持し、TAB で1段進めること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (my-haskell-simple-indent-setup)
    (insert "      mapM_")
    (call-interactively (key-binding (kbd "RET")))
    (should (= (current-indentation) 6))
    (call-interactively (key-binding (kbd "TAB")))
    (should (= (current-indentation) 8))
    (should (= (current-column) 8))))

(ert-deftest my/haskell-simple-indent-ret-after-blank-line-workflow ()
  "空行を挟んでも RET で直近のコード行の深さを維持すること。"
  (with-temp-buffer
    (setq-local my-haskell-simple-indent-offset 2)
    (my-haskell-simple-indent-setup)
    (insert "      topChunks <- searchChunks queryVector\n")
    (call-interactively (key-binding (kbd "RET")))
    (should (= (current-indentation) 6))
    (should (= (current-column) 6))))

;;; my-haskell-simple-indent-test.el ends here
