;;; my-eglot.el --- Haskell completion compatibility -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs 31.1 Eglot applies a completion item's text edits but does not
;; execute CompletionItem.command.  HLS uses that command to add imports
;; when completing an out-of-scope name.  Keep Eglot's normal exit
;; function and run the server command only after it succeeds.
;;
;; Recheck this workaround when upgrading Eglot: it must be removed once
;; Eglot executes CompletionItem.command itself.

;;; Code:

(declare-function eglot-current-server "eglot" ())
(declare-function eglot-execute "eglot" (server action))

(defun my/eglot-haskell-completion-command (capf)
  "Run the Haskell completion item's server command after CAPF's exit.
This is a :filter-return advice for eglot-completion-at-point."
  (when (and (consp capf) (derived-mode-p 'haskell-ts-mode))
    (when-let* ((exit (plist-get (nthcdr 3 capf) :exit-function))
                (server (eglot-current-server)))
      (plist-put (nthcdr 3 capf) :exit-function
            (lambda (candidate status)
              (let* ((item (when (and (stringp candidate)
                                      (> (length candidate) 0))
                             (get-text-property 0 'eglot--lsp-item candidate)))
                     (command (and (memq status '(finished exact))
                                   (plist-get item :command))))
                ;; The original function handles text edits, snippets,
                ;; resolution and didChange.  Do not replace its behavior.
                (funcall exit candidate status)
                (when command
                  ;; eglot-execute removes :title from Command objects.
                  ;; Keep the CompletionItem intact for any later use.
                  (eglot-execute server (copy-tree command))))))))
  capf)

(provide 'my-eglot)

;;; my-eglot.el ends here
