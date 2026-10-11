;;; my-project-command-prompt-test.el --- Command prompt ERT -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for selecting commands, entering questions, and validating local settings.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-project)

(defun my/project-prompt-test--run (commands answers)
  "Run COMMANDS using minibuffer ANSWERS and record observable effects."
  (let (reads executed directory shown error)
    (cl-letf (((symbol-function 'project-current)
               (lambda (&rest _args) 'project))
              ((symbol-function 'project-root)
               (lambda (_project) "/tmp/my-project-test/"))
              ((symbol-function 'my/project-command--get-project-commands)
               (lambda (root)
                 (should (equal root "/tmp/my-project-test/"))
                 commands))
              ((symbol-function 'completing-read)
               (lambda (prompt collection predicate require-match &rest _args)
                 (push (list prompt collection predicate require-match) reads)
                 (prog1 (car answers)
                   (setq answers (cdr answers)))))
              ((symbol-function 'compile)
               (lambda (command)
                 (setq executed command
                       directory default-directory)
                 'compilation-buffer))
              ((symbol-function 'pop-to-buffer)
               (lambda (buffer &rest _args)
                 (setq shown buffer))))
      (condition-case caught
          (my/project-run-command)
        (user-error (setq error caught))))
    (list :reads (nreverse reads)
          :command executed
          :directory directory
          :buffer shown
          :error error)))

(ert-deftest my/project-run-command-plain-command ()
  "Commands without :prompt still run without asking for an argument."
  (let* ((commands
          '(("Build" :command "cabal build" :description "Build project")))
         (result (my/project-prompt-test--run commands '("Build"))))
    (should (equal (plist-get result :reads)
                   (list (list "Command: " commands nil t))))
    (should (equal (plist-get result :command) "cabal build"))
    (should (equal (plist-get result :directory) "/tmp/my-project-test/"))
    (should (eq (plist-get result :buffer) 'compilation-buffer))
    (should-not (plist-get result :error))))

(ert-deftest my/project-run-command-registered-question ()
  "The chosen candidate is quoted and passed as an argument."
  (let* ((candidates '("pgvectorは何をするものですか？" "RAGとは？"))
         (question (car candidates))
         (commands
          (list (list "Run query" :command "cabal run rag-lab -- query"
                      :description "RAGに質問する" :prompt "質問: "
                      :candidates candidates)))
         (result (my/project-prompt-test--run
                  commands (list "Run query" question))))
    (should (equal (plist-get result :reads)
                   (list (list "Command: " commands nil t)
                         (list "質問: " candidates nil nil))))
    (should (equal (plist-get result :command)
                   (concat "cabal run rag-lab -- query "
                           (shell-quote-argument question))))
    (should-not (plist-get result :error))))

(ert-deftest my/project-run-command-free-question ()
  "Questions outside the candidate list are accepted and safely quoted."
  (let* ((question "自由入力 '引用' ; $(echo test)")
         (candidates '("登録済みの質問"))
         (commands
          (list (list "Run query" :command "cabal run rag-lab -- query"
                      :description "RAGに質問する" :prompt "質問: "
                      :candidates candidates)))
         (result (my/project-prompt-test--run
                  commands (list "Run query" question))))
    (should-not (member question candidates))
    (should (equal (plist-get result :reads)
                   (list (list "Command: " commands nil t)
                         (list "質問: " candidates nil nil))))
    (should (equal (plist-get result :command)
                   (concat "cabal run rag-lab -- query "
                           (shell-quote-argument question))))
    (should-not (plist-get result :error))))

(ert-deftest my/project-run-command-empty-question ()
  "An empty question raises a user error and does not run compile."
  (let* ((commands '(("Run query" :command "rag-lab query"
                      :description "RAGに質問する" :prompt "質問: ")))
         (result (my/project-prompt-test--run
                  commands '("Run query" ""))))
    (should (eq (car (plist-get result :error)) 'user-error))
    (should-not (plist-get result :command))
    (should-not (plist-get result :buffer))))

(ert-deftest my/project-run-command-no-commands ()
  "Without configured commands there is no completion or execution."
  (let ((result (my/project-prompt-test--run nil nil)))
    (should (eq (car (plist-get result :error)) 'user-error))
    (should-not (plist-get result :reads))
    (should-not (plist-get result :command))))

(ert-deftest my/project-commands-safe-p-prompt-and-candidates ()
  "String prompts and candidate lists are accepted."
  (should (my/project-commands-safe-p
           '(("Run query" :command "rag-lab query"
              :description "RAGに質問する" :prompt "質問: "
              :candidates ("pgvectorとは？" "RAGとは？"))))))

(ert-deftest my/project-commands-safe-p-non-string-prompt ()
  "A non-string prompt is unsafe."
  (should-not (my/project-commands-safe-p
               '(("Run query" :command "rag-lab query"
                  :description "RAGに質問する" :prompt 123)))))

(ert-deftest my/project-commands-safe-p-non-list-candidates ()
  "A candidate value other than a list is unsafe."
  (should-not (my/project-commands-safe-p
               '(("Run query" :command "rag-lab query"
                  :description "RAGに質問する"
                  :candidates "pgvectorとは？")))))

(ert-deftest my/project-commands-safe-p-non-string-candidate ()
  "A candidate list containing a non-string entry is unsafe."
  (should-not (my/project-commands-safe-p
               '(("Run query" :command "rag-lab query"
                  :description "RAGに質問する"
                  :candidates ("RAGとは？" 123))))))


;;; my-project-command-prompt-test.el ends here
