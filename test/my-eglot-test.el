;;; my-eglot-test.el --- Eglot completion integration tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Verify that the Haskell-only CAPF wrapper preserves Eglot's exit
;; behavior and executes a CompletionItem.command only on acceptance.
;; Tests do not start a language server.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-eglot)

(ert-deftest my/eglot-haskell-completion-executes-import-after-original-exit ()
  "Accepting an HLS item executes its command after Eglot's edits."
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let* ((command '(:title "extend import"
                     :command "hls:ghcide-extend-import-action:extendImport"
                     :arguments [(:newThing "encode")]))
           (item (list :label "encode" :command command))
           (candidate (propertize "encode" 'eglot--lsp-item item))
           (events nil)
           (capf (list 1 4 nil :exit-function
                       (lambda (_candidate _status)
                         (push 'original events)))))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (server action)
                   (should (eq server 'test-hls))
                   (should (equal (plist-get action :command)
                                  (plist-get command :command)))
                   (push 'command events)
                   ;; Eglot may destructively remove :title.
                   (cl-remf action :title))))
        (should (eq capf (my/eglot-haskell-completion-command capf)))
        (funcall (plist-get (nthcdr 3 capf) :exit-function)
                 candidate 'finished)
        (should (equal (nreverse events) '(original command)))
        (should (equal (plist-get command :title) "extend import"))))))

(ert-deftest my/eglot-haskell-completion-supports-exact-status ()
  "An exact completion also executes its command."
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let ((count 0)
          (candidate (propertize "encode" 'eglot--lsp-item
                                 '(:command (:title "extend import"
                                             :command "extendImport"))))
          (capf (list 1 4 nil :exit-function #'ignore)))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (_server _action) (cl-incf count))))
        (my/eglot-haskell-completion-command capf)
        (funcall (plist-get (nthcdr 3 capf) :exit-function) candidate 'exact)
        (should (= count 1))))))

(ert-deftest my/eglot-haskell-completion-ignores-cancel-and-unmarked-candidates ()
  "Do not run commands after cancel or for non-LSP candidates."
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let* ((count 0)
           (candidate (propertize "encode" 'eglot--lsp-item
                                  '(:command (:title "extend import"
                                              :command "extendImport"))))
           (capf (list 1 4 nil :exit-function
                       (lambda (_candidate _status) (cl-incf count)))))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (&rest _) (ert-fail "Unexpected server command"))))
        (my/eglot-haskell-completion-command capf)
        (let ((exit (plist-get (nthcdr 3 capf) :exit-function)))
          (funcall exit candidate 'cancelled)
          (funcall exit "encode" 'finished)
          (funcall exit (propertize "encode" 'eglot--lsp-item
                                   '(:label "encode")) 'finished))
        (should (= count 3))))))

(ert-deftest my/eglot-haskell-completion-leaves-other-modes-unchanged ()
  "Other major modes keep the original Eglot completion callback."
  (with-temp-buffer
    (let* ((original #'ignore)
           (capf (list 1 4 nil :exit-function original)))
      (setq-local major-mode 'python-ts-mode)
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () (ert-fail "Should not inspect Eglot server"))))
        (should (eq capf (my/eglot-haskell-completion-command capf)))
        (should (eq original
                    (plist-get (nthcdr 3 capf) :exit-function)))))))

(ert-deftest my/eglot-haskell-completion-does-not-execute-after-exit-error ()
  "Do not execute server commands if the original completion fails."
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let* ((candidate (propertize "encode" 'eglot--lsp-item
                                  '(:command (:title "extend import"
                                              :command "extendImport"))))
           (capf (list 1 4 nil :exit-function
                       (lambda (&rest _) (error "Original exit failed")))))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (&rest _) (ert-fail "Should not execute"))))
        (my/eglot-haskell-completion-command capf)
        (should-error (funcall (plist-get (nthcdr 3 capf) :exit-function)
                               candidate 'finished))))))

;;; my-eglot-test.el ends here
