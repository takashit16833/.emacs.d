;;; my-org-commands-test.el --- Tests for my-org-commands -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for personal Org commands.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
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


(ert-deftest my-org-insert-created-inserts-after-org-metadata ()
  "カーソル位置に関係なく、Org メタ情報の直後へ CREATED を追加すること。"
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task\n"
            "SCHEDULED: <2026-10-16 Fri>\n"
            ":PROPERTIES:\n"
            ":CATEGORY: Test\n"
            ":END:\n"
            "本文\n"
            "** TODO Child\n")
    ;; 見出し行ではなく本文上から実行する。
    (goto-char (point-min))
    (search-forward "本文")
    (cl-letf (((symbol-function 'org-timestamp-inactive)
               (lambda (arg)
                 (should (equal arg '(16)))
                 (insert "[NOW]"))))
      (my/org-insert-created))
    (should
     (equal
      (buffer-string)
      (concat "* TODO Task\n"
              "SCHEDULED: <2026-10-16 Fri>\n"
              ":PROPERTIES:\n"
              ":CATEGORY: Test\n"
              ":END:\n"
              "  CREATED: [NOW]\n"
              "本文\n"
              "** TODO Child\n")))))


(ert-deftest my-org-insert-created-rejects-duplicate ()
  "現在の見出しに CREATED が既にあれば重複して追加しないこと。"
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task\n"
            "  CREATED: [2026-10-15 Thu 10:30]\n"
            "本文\n")
    (goto-char (point-max))
    (should-error (my/org-insert-created) :type 'user-error)))


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
