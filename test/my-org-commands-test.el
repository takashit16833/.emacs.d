;;; my-org-commands-test.el --- Tests for my-org-commands -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for personal Org commands.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-org-commands)


(ert-deftest my-org-home-toggle-opens-home ()
  "Org Home 以外では、現在のバッファを保存して Org Home を開くこと。"
  (let ((org-default-notes-file "/tmp/notes.org")
        (my/org-home--return-buffer nil)
        opened-file)
    (with-temp-buffer
      (let ((source-buffer (current-buffer)))
        (cl-letf (((symbol-function 'find-file)
                   (lambda (file)
                     (setq opened-file file))))
          (my/org-home-toggle)
          (should (eq my/org-home--return-buffer source-buffer))
          (should (equal opened-file "/tmp/notes.org")))))))


(ert-deftest my-org-home-toggle-returns-to-previous-buffer ()
  "Org Home では、開く前に表示していたバッファへ戻ること。"
  (let ((org-default-notes-file "/tmp/notes.org")
        (return-buffer (generate-new-buffer " *org-home-return*"))
        (home-buffer (generate-new-buffer " *org-home*"))
        switched-buffer)
    (unwind-protect
        (let ((my/org-home--return-buffer return-buffer))
          (with-current-buffer home-buffer
            (setq buffer-file-name "/tmp/notes.org")
            (cl-letf (((symbol-function 'switch-to-buffer)
                       (lambda (buffer-or-name &rest _args)
                         (setq switched-buffer buffer-or-name))))
              (my/org-home-toggle)
              (should (eq switched-buffer return-buffer))
              (should-not my/org-home--return-buffer))))
      (kill-buffer return-buffer)
      (kill-buffer home-buffer))))


(ert-deftest my-org-capture-inbox-uses-inbox-template ()
  "Inbox 用キーを指定して Org Capture を開始すること。"
  (let (arguments)
    (cl-letf (((symbol-function 'org-capture)
               (lambda (&rest args)
                 (setq arguments args))))
      (my/org-capture-inbox)
      (should (equal arguments '(nil "i"))))))


(ert-deftest my-org-insert-child-task-inserts-todo-subheading ()
  "TODO の子見出しを追加すること。"
  (let ((argument :unset))
    (cl-letf (((symbol-function 'org-insert-todo-subheading)
               (lambda (arg)
                 (setq argument arg))))
      (my/org-insert-child-task)
      (should-not argument))))


(provide 'my-org-commands-test)

;;; my-org-commands-test.el ends here
