((nil . ((my/project-commands
          . (("All tests"
              :command "emacs -Q --batch -L elisp -L test --eval \"(progn (mapc #'load-file (directory-files \\\"test\\\" t \\\"-test[.]el$\\\")) (ert-run-tests-batch-and-exit))\""
              :description "外部パッケージ不要の単体テストを実行する")
             ("HLS resolve integration"
              :command "emacs -Q --batch -L elisp --eval \"(package-initialize)\" -l test/my-development-lsp-integration.el --eval \"(ert-run-tests-batch-and-exit \\\"my/lsp-integration-\\\")\""
              :description "実際のlsp-modeでHLS補完のJSON送信を検証する"))))))
