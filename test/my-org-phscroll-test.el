;;; my-org-phscroll-test.el --- Org horizontal scroll tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'my-org-phscroll)

(ert-deftest my/org-phscroll-uses-visible-indent-width ()
  "Use line-prefix instead of wrap-prefix only in Org scroll regions."
  (with-temp-buffer
    (org-mode)
    (insert "  long source line\n")
    (let ((pos (point-min)))
      (put-text-property pos (point-max) 'line-prefix "    ")
      (put-text-property pos (point-max) 'wrap-prefix (make-string 18 ?\s))
      (setq-local my/org-phscroll-mode t)
      (should (= 109 (my/org-phscroll--window-width
                      (lambda (&rest _) 95) pos (selected-window))))
      (setq-local my/org-phscroll-mode nil)
      (should (= 95 (my/org-phscroll--window-width
                     (lambda (&rest _) 95) pos (selected-window)))))))

(ert-deftest my/org-phscroll-selects-tables-and-block-contents ()
  "Do not mistake pipe text inside a block for an independent table."
  (with-temp-buffer
    (insert "| Name | Note |\n|------+------|\n| A    | Long |\n\n"
            "#+begin_src yaml\n  key: very-long-value\n  | not a table |\n#+end_src\n\n"
            "#+begin_example\n  example output\n#+end_example\n"
            "Regular text\n")
    (org-mode)
    (let* ((regions (my/org-phscroll--regions))
           (starts
            (mapcar (lambda (region)
                      (save-excursion
                        (goto-char (car region))
                        (buffer-substring-no-properties
                         (line-beginning-position) (line-end-position))))
                    regions)))
      (should (equal starts
                     '("| Name | Note |"
                       "  key: very-long-value"
                       "  example output")))
      (dolist (region regions)
        (let ((raw (buffer-substring-no-properties
                    (car region) (cdr region))))
          (should-not (string-match-p "#\\+begin_" raw))
          (should-not (string-match-p "#\\+end_" raw)))))))

(ert-deftest my/org-phscroll-refresh-reuses-unchanged-areas ()
  "Refreshing an unchanged Org file does not recreate scroll areas."
  (with-temp-buffer
    (insert "| A | B |\n|---+---|\n| 1 | 2 |\n")
    (org-mode)
    (let ((areas nil)
          (created 0)
          (destroyed 0))
      (setq-local my/org-phscroll-mode t)
      (cl-letf (((symbol-function 'phscroll-enum-area)
                 (lambda (&rest _) areas))
                ((symbol-function 'phscroll-area-begin) #'car)
                ((symbol-function 'phscroll-area-end) #'cdr)
                ((symbol-function 'phscroll-region)
                 (lambda (beg end)
                   (cl-incf created)
                   (push (cons beg end) areas)))
                ((symbol-function 'phscroll-area-destroy)
                 (lambda (area)
                   (cl-incf destroyed)
                   (setq areas (delq area areas)))))
        (my/org-phscroll-refresh)
        (should (= created 1))
        (my/org-phscroll-refresh)
        (should (= created 1))
        (should (= destroyed 0))
        (should (= (length areas) 1))))))

(provide 'my-org-phscroll-test)
;;; my-org-phscroll-test.el ends here
