;;; my-org-indent-test.el --- Tests for Org wrap backgrounds -*- lexical-binding: t; -*-

;;; Commentary:
;; Verify that source block wrap prefixes are colored during Org updates.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-indent)
(require 'my-org-indent)

(defun my/org-indent-test--wrap-face (text)
  "Return the wrap-prefix face on the line containing TEXT."
  (save-excursion
    (goto-char (point-min))
    (search-forward text)
    (let ((prefix (get-text-property (line-beginning-position) 'wrap-prefix)))
      (and (stringp prefix)
           (get-text-property 0 'face prefix)))))

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
              (should (equal (my/org-indent-test--wrap-face "key: value") colored))
              (should (equal (my/org-indent-test--wrap-face "nested: long-value")
                             colored))
              (dolist (text '("Before block" "#+begin_src" "#+end_src"
                              "After block" "fake: yaml"))
                (should (eq (my/org-indent-test--wrap-face text) 'org-indent)))
              ;; Org must be able to recreate indentation without losing the fix.
              (org-indent-indent-buffer)
              (should (equal (my/org-indent-test--wrap-face "key: value")
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
          (should (equal (my/org-indent-test--wrap-face "second: value")
                         '(:inherit org-indent :background "#0A1A36")))
          (should (eq (my/org-indent-test--wrap-face "Outside") 'org-indent)))
      (org-indent-mode -1))))

(provide 'my-org-indent-test)

;;; my-org-indent-test.el ends here
