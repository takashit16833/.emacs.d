((nil . ((my/project-commands
          . (("All tests"
              :command "emacs -Q --batch -L elisp -L test --eval "(progn (mapc #'load-file (directory-files \"test\" t \"-test[.]el$\")) (ert-run-tests-batch-and-exit))""
              :description "testフォルダのすべてのテストを実行する"))))))
