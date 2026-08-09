(require 'cl-lib)
(require 'org)
(require 'org-capture)
(require 'bookmark)
(require 'subr-x)

(defun test/assert (condition message)
  (unless condition
    (error "ASSERTION FAILED: %s" message)))

(defun test/literal-field-present-p (field)
  (pcase-let ((`(,begin . ,end)
               (my/org-workflow-body-bounds)))
    (save-excursion
      (goto-char begin)
      (re-search-forward
       (format "^[ \t]*- %s:[ \t]*.*$" (regexp-quote field))
       end
       t))))

(let* ((root (make-temp-file "cockpit-workflow-" t))
       (my/task-inbox-file (expand-file-name "inbox.org" root))
       (my/task-cockpit-file (expand-file-name "cockpit.org" root)))
  (write-region
   "#+TODO: TODO(t) | DONE(x) DROP(k)\n* Inbox\n** TODO Sample\n"
   nil my/task-inbox-file nil 'silent)
  (write-region
   "#+TODO: TODO(t) NEXT(n) DOING(d) HOLD(h) WAIT(w) | DONE(x) DROP(k)\n* Work Items\n"
   nil my/task-cockpit-file nil 'silent)

  (load "/tmp/cockpit-workflow.el" nil nil t)

  (let* ((inbox-buffer (find-file-noselect my/task-inbox-file))
         (source-marker
          (with-current-buffer inbox-buffer
            (goto-char (point-min))
            (re-search-forward "^\\*\\* TODO Sample$")
            (copy-marker (line-beginning-position))))
         doing-marker)

    ;; Inbox -> Doing: refile, TODO state and required field.
    (cl-letf (((symbol-function 'read-string)
               (lambda (&rest _) "Implement parser")))
      (setq doing-marker
            (my/org-change-task-state-at-marker source-marker "Doing")))

    (org-with-point-at doing-marker
      (test/assert
       (file-equal-p (buffer-file-name) my/task-cockpit-file)
       "Doing item was not moved to cockpit.org")
      (test/assert (equal (org-get-todo-state) "DOING")
                   "Doing TODO state is wrong")
      (test/assert
       (equal (my/org-workflow-field-value "次の一手")
              "Implement parser")
       "Doing next action was not written"))

    ;; Child positions normalize to the level-2 work item.
    (org-with-point-at doing-marker
      (org-end-of-subtree t t)
      (insert "*** Child note\n")
      (let ((child-marker (copy-marker (line-beginning-position))))
        (unwind-protect
            (let ((root-marker (my/org-task-item-marker child-marker)))
              (unwind-protect
                  (org-with-point-at root-marker
                    (test/assert (= (org-outline-level) 2)
                                 "Child did not normalize to level 2")
                    (test/assert (equal (org-get-heading t t t t) "Sample")
                                 "Child normalized to wrong work item"))
                (set-marker root-marker nil)))
          (set-marker child-marker nil)))
      (save-buffer))

    ;; Doing -> Hold: fields are replaced and returned marker remains on heading.
    (let ((responses '("Resume at parser spec" "Interrupt task")))
      (cl-letf (((symbol-function 'read-string)
                 (lambda (&rest _)
                   (prog1 (car responses)
                     (setq responses (cdr responses))))))
        (setq doing-marker
              (my/org-change-task-state-at-marker doing-marker "Hold"))))

    (org-with-point-at doing-marker
      (test/assert (org-at-heading-p)
                   "Returned Hold marker is not on heading")
      (test/assert (equal (org-get-todo-state) "HOLD")
                   "Hold TODO state is wrong")
      (test/assert
       (equal (my/org-workflow-field-value "再開時の一手")
              "Resume at parser spec")
       "Hold resume action was not written")
      (test/assert
       (equal (my/org-workflow-field-value "中断理由")
              "Interrupt task")
       "Hold reason was not written")
      (test/assert
       (not (test/literal-field-present-p "次の一手"))
       "Obsolete Doing field remained after Hold"))

    ;; C-g happens before any mutation.
    (let ((before-inbox
           (with-temp-buffer
             (insert-file-contents my/task-inbox-file)
             (buffer-string)))
          (before-cockpit
           (with-temp-buffer
             (insert-file-contents my/task-cockpit-file)
             (buffer-string)))
          quit-seen)
      (condition-case nil
          (cl-letf (((symbol-function 'read-string)
                     (lambda (&rest _) (signal 'quit nil))))
            (my/org-change-task-state-at-marker doing-marker "Wait"))
        (quit (setq quit-seen t)))
      (test/assert quit-seen "C-g/quit did not abort prompting")
      (test/assert
       (equal before-inbox
              (with-temp-buffer
                (insert-file-contents my/task-inbox-file)
                (buffer-string)))
       "Inbox changed after cancelled transition")
      (test/assert
       (equal before-cockpit
              (with-temp-buffer
                (insert-file-contents my/task-cockpit-file)
                (buffer-string)))
       "Cockpit changed after cancelled transition"))

    ;; Hold -> Inbox: refile, TODO and field cleanup.
    (let ((inbox-marker
           (my/org-change-task-state-at-marker doing-marker "Inbox")))
      (unwind-protect
          (org-with-point-at inbox-marker
            (test/assert
             (file-equal-p (buffer-file-name) my/task-inbox-file)
             "Inbox transition did not move item to inbox.org")
            (test/assert (equal (org-get-todo-state) "TODO")
                         "Inbox TODO state is wrong")
            (dolist (field my/org-workflow-managed-fields)
              (test/assert
               (not (test/literal-field-present-p field))
               (format "Managed field remained in Inbox: %s" field))))
        (set-marker inbox-marker nil)))

    ;; Level-1 container must not be transitioned as a work item.
    (let ((root-error nil))
      (with-current-buffer (find-file-noselect my/task-cockpit-file)
        (goto-char (point-min))
        (re-search-forward "^\\* Work Items$")
        (condition-case nil
            (my/org-task-item-marker (copy-marker (line-beginning-position)))
          (user-error (setq root-error t))))
      (test/assert root-error
                   "Level-1 Work Items heading was accepted as a task"))

    (set-marker source-marker nil)
    (when (markerp doing-marker)
      (set-marker doing-marker nil))))

(princ "COCKPIT_WORKFLOW_TESTS_OK\n")
