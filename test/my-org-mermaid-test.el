;;; my-org-mermaid-test.el --- ERT tests for Mermaid previews -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'my-org-mermaid)

(ert-deftest my-org-mermaid-output-file-is-content-addressed ()
  "Source and output-affecting headers determine a persistent path."
  (let* ((my/org-mermaid-image-directory "/tmp/example-mermaid/")
         (info '("mermaid" "flowchart LR\nA-->B"
                 ((:theme . "dark") (:results . "file"))))
         (original (my/org-mermaid--output-file info)))
    (should (equal original (my/org-mermaid--output-file info)))
    (should (string-prefix-p my/org-mermaid-image-directory original))
    (should (string-suffix-p ".png" original))
    (setcar (cdr info) "flowchart LR\nA-->C")
    (should-not (equal original (my/org-mermaid--output-file info)))
    (setcar (cdr info) "flowchart LR\nA-->B")
    (setcdr (assq :theme (nth 2 info)) "neutral")
    (should-not (equal original (my/org-mermaid--output-file info)))))

(ert-deftest my-org-mermaid-output-file-ignores-babel-output-options ()
  "Changing a manual :file or :results does not affect cached pixels."
  (let* ((info '("mermaid" "A-->B" ((:theme . "dark"))))
         (original (my/org-mermaid--output-file info)))
    (setf (nth 2 info) (append (nth 2 info)
                               '((:file . "temporary.png")
                                 (:results . "file"))))
    (should (equal original (my/org-mermaid--output-file info)))))

(ert-deftest my-org-mermaid-preview-reuses-output ()
  "Mermaid is executed on the first request, not on an unchanged repeat."
  (let ((dir (make-temp-file "my-org-mermaid-test-" t))
        (runs 0)
        (insertions 0)
        (my/org-mermaid-image-directory nil))
    (unwind-protect
        (progn
          (setq my/org-mermaid-image-directory dir)
          (with-temp-buffer
            (org-mode)
            (insert "#+begin_src mermaid\nflowchart LR\nA-->B\n#+end_src\n")
            (goto-char (point-min))
            (cl-letf (((symbol-function 'org-babel-execute-src-block)
                       (lambda (_arg _info params &rest _)
                         (setq runs (1+ runs))
                         (let ((file (cdr (assq :file params))))
                           (with-temp-file file
                             (insert "mock PNG")))))
                      ((symbol-function 'org-babel-insert-result)
                       (lambda (&rest _) (setq insertions (1+ insertions))))
                      ((symbol-function 'org-display-inline-images)
                       (lambda (&rest _) nil)))
              (let ((first (my/org-mermaid-preview)))
                (should (file-exists-p first))
                (should (= runs 1))
                (should (equal first (my/org-mermaid-preview)))
                (should (= runs 1))
                (should (= insertions 1))
                ;; Changing the source requires another image.
                (search-forward "A-->B")
                (replace-match "A-->C")
                (goto-char (point-min))
                (should-not (equal first (my/org-mermaid-preview)))
                (should (= runs 2))))))
      (delete-directory dir t))))

(ert-deftest my-org-mermaid-preview-rejects-other-blocks ()
  (with-temp-buffer
    (org-mode)
    (insert "#+begin_src python\nprint(1)\n#+end_src\n")
    (goto-char (point-min))
    (should-error (my/org-mermaid-preview) :type 'user-error)))

(ert-deftest my-org-mermaid-failed-render-removes-partial-png ()
  (let* ((dir (make-temp-file "my-org-mermaid-failed-" t))
         (my/org-mermaid-image-directory dir)
         (output nil))
    (unwind-protect
        (with-temp-buffer
          (org-mode)
          (insert "#+begin_src mermaid\nA-->B\n#+end_src\n")
          (goto-char (point-min))
          (setq output (my/org-mermaid--output-file
                        (org-babel-get-src-block-info)))
          (cl-letf (((symbol-function 'org-babel-execute-src-block)
                     (lambda (_arg _info params &rest _)
                       (with-temp-file (cdr (assq :file params))
                         (insert "partial"))
                       (error "mmdc failed"))))
            (should-error (my/org-mermaid-preview))
            (should-not (file-exists-p output))))
      (delete-directory dir t))))

;;; my-org-mermaid-test.el ends here
