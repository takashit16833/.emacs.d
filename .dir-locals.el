((nil . ((my/project-commands
          . (("All tests"
              :command "sh test/run-all-tests.sh"
              :description "単体テストとすべての結合テストを実行する")
             ("HLS resolve integration"
              :command "emacs -Q --batch -L elisp --eval \"(package-initialize)\" -l test/my-development-lsp-integration.el --eval \"(ert-run-tests-batch-and-exit \\\"my/lsp-integration-\\\")\""
              :description "実際のlsp-modeでHLS補完のJSON送信を検証する"))))))
