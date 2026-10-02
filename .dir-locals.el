((nil . ((my/project-commands
          . (("All tests"
              :command "emacs -Q --batch -L lisp -L test --eval \"(progn (mapc #'load-file (directory-files \\\"test\\\" t \\\"\\\\.el\\\\'\\\")) (ert-run-tests-batch-and-exit))\""
              :description "testフォルダのすべてのテストを実行する"))))))
