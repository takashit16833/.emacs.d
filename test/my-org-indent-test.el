;;; my-org-indent-test.el --- Tests for Org wrap backgrounds -*- lexical-binding: t; -*-

;;; Commentary:
;; Verify that source block wrap prefixes are colored during Org updates.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-indent)
(require 'my-org-indent)

(defun my/org-indent-test--wrap-face (text &optional after-line-prefix)
  "Return the wrap face on TEXT's line.
When AFTER-LINE-PREFIX is non-nil, inspect the first code-indent cell."
  (save-excursion
    (goto-char (point-min))
    (search-forward text)
    (let* ((beg (line-beginning-position))
           (line (get-text-property beg 'line-prefix))
           (wrap (get-text-property beg 'wrap-prefix)))
      (when (and (stringp line) (stringp wrap))
        (get-text-property (if after-line-prefix (length line) 0)
                           'face wrap)))))

(ert-deftest my-org-indent-source-wrap-only ()
  "Color source continuations, but neither normal text nor delimiters."
  (with-temp-buffer
    (org-mode)
    (insert "* Heading\nBefore block\n"
            "#+begin_src yaml\n  key: value\n    nested: long-value\n#+end_src\n"
            "After block\n"
            "#+begin_example\n#+begin_src yaml\n  fake: yaml\n"
            "#+end_src\n#+end_example\n")
    (let ((org-indent-indentation-per-level 2))
      (org-indent-mode 1)
      (unwind-protect
          (cl-letf (((symbol-function 'my/org-indent--source-background)
                     (lambda () "#0A1A36")))
            (org-indent-indent-buffer)
            (let ((colored '(:inherit org-indent :background "#0A1A36")))
              (should (eq (my/org-indent-test--wrap-face "key: value") 'org-indent))
              (should (eq (my/org-indent-test--wrap-face "nested: long-value")
                          'org-indent))
              (should (equal (my/org-indent-test--wrap-face "key: value" t)
                             colored))
              (should (equal (my/org-indent-test--wrap-face "nested: long-value" t)
                             colored))
              (dolist (text '("Before block" "#+begin_src" "#+end_src"
                              "After block" "fake: yaml"))
                (should (eq (my/org-indent-test--wrap-face text) 'org-indent)))
              ;; Org must be able to recreate indentation without losing the fix.
              (org-indent-indent-buffer)
              (should (eq (my/org-indent-test--wrap-face "key: value")
                          'org-indent))
              (should (equal (my/org-indent-test--wrap-face "key: value" t)
                             colored))))
        (org-indent-mode -1)))))

(ert-deftest my-org-indent-source-wrap-partial-refresh ()
  "Keep the source state when indentation starts halfway through a block."
  (with-temp-buffer
    (org-mode)
    (insert "* Heading\n#+begin_src yaml\n  first: value\n  second: value\n"
            "#+end_src\nOutside\n")
    (org-indent-mode 1)
    (unwind-protect
        (cl-letf (((symbol-function 'my/org-indent--source-background)
                   (lambda () "#0A1A36")))
          (org-indent-indent-buffer)
          (goto-char (point-min))
          (search-forward "second: value")
          (let ((beg (line-beginning-position)))
            (org-indent-add-properties beg (line-end-position)))
          (should (eq (my/org-indent-test--wrap-face "second: value")
                      'org-indent))
          (should (equal (my/org-indent-test--wrap-face "second: value" t)
                         '(:inherit org-indent :background "#0A1A36")))
          (should (eq (my/org-indent-test--wrap-face "Outside") 'org-indent)))
      (org-indent-mode -1))))

(ert-deftest my-org-indent-source-wrap-preserves-heading-padding ()
  "Color only code indentation after the heading's virtual prefix."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n** Heading\n#+begin_src yaml\n"
            (make-string 18 ?\s)
            "deep: value\n#+end_src\n")
    (let ((org-indent-indentation-per-level 2))
      (org-indent-mode 1)
      (unwind-protect
          (cl-letf (((symbol-function 'my/org-indent--source-background)
                     (lambda () "#0A1A36")))
            (org-indent-indent-buffer)
            (goto-char (point-min))
            (search-forward "deep: value")
            (let* ((beg (line-beginning-position))
                   (line (get-text-property beg 'line-prefix))
                   (wrap (get-text-property beg 'wrap-prefix)))
              (should (= (length line) 4))
              (should (= (length wrap) 22))
              (should (eq (get-text-property 0 'face line) 'org-indent))
              (should (eq (get-text-property 0 'face wrap) 'org-indent))
              (should (eq (get-text-property 3 'face wrap) 'org-indent))
              (should (equal (get-text-property 4 'face wrap)
                             '(:inherit org-indent :background "#0A1A36")))))
        (org-indent-mode -1)))))


(provide 'my-org-indent-test)

;;; my-org-indent-test.el ends here
