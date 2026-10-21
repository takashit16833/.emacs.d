((nil . ((my/project-commands
          . (("All tests"
              :command "sh test/run-all-tests.sh"
              :description "単体テストとすべての結合テストを実行する")
             ("Unit tests"
              :command "emacs -Q --batch -L elisp -L test --eval \"(progn (mapc #'load-file (directory-files \\\"test\\\" t \\\"-test[.]el$\\\")) (ert-run-tests-batch-and-exit))\""
              :description "外部パッケージ不要のERT単体テストを実行する")
             ("Byte-compile"
              :command "emacs -Q --batch -L elisp --eval \"(progn (setq user-emacs-directory default-directory) (package-initialize) (load-file \\\"elisp/my-basic.el\\\") (my/byte-compile-config))\""
              :description "更新されたconfig/とelisp/をバイトコンパイルする"))))))
