;;; my-prog-phscroll-test.el --- Program buffer horizontal scroll tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'my-prog-phscroll)

(ert-deftest my/prog-phscroll-sync-reuses-unchanged-area ()
  "Do not recreate the region on an unchanged source buffer."
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert "(message \"a long line\")\n")
    (let ((calls 0)
          (area nil))
      (setq-local my/prog-phscroll-mode t)
      (cl-letf (((symbol-function 'phscroll-region)
                 (lambda (beg end)
                   (cl-incf calls)
                   (setq area (cons beg end))))
                ((symbol-function 'phscroll-area-begin) #'car)
                ((symbol-function 'phscroll-area-end) #'cdr))
        (my/prog-phscroll--sync)
        (should (equal area (cons (point-min) (point-max))))
        (my/prog-phscroll--sync)
        (should (= calls 1))
        (goto-char (point-max))
        (insert "(message \"another line\")\n")
        (my/prog-phscroll--sync)
        (should (= calls 2))
        (should (equal area (cons (point-min) (point-max))))))))

(ert-deftest my/prog-phscroll-sync-empty-buffer ()
  "Do not register a horizontal scroll region in an empty buffer."
  (with-temp-buffer
    (emacs-lisp-mode)
    (let ((calls 0))
      (setq-local my/prog-phscroll-mode t)
      (cl-letf (((symbol-function 'phscroll-region)
                 (lambda (&rest _) (cl-incf calls))))
        (my/prog-phscroll--sync)
        (should (= calls 0))))))

(ert-deftest my/prog-phscroll-eligibility ()
  "Support code files, including YAML, without affecting prose or Org."
  (require 'yaml-ts-mode)
  (with-temp-buffer
    (emacs-lisp-mode)
    (should-not (my/prog-phscroll--eligible-p))
    (setq buffer-file-name "/tmp/test.el")
    (should (my/prog-phscroll--eligible-p)))
  ;; yaml-ts-mode in Emacs 31 inherits from text-mode, not prog-mode.
  ;; Set major-mode directly to avoid requiring an installed YAML grammar.
  (with-temp-buffer
    (setq buffer-file-name "/tmp/test.yaml")
    (setq major-mode 'yaml-ts-mode)
    (should (derived-mode-p 'yaml-mode))
    (should (my/prog-phscroll--eligible-p)))
  (with-temp-buffer
    (text-mode)
    (setq buffer-file-name "/tmp/notes.txt")
    (should-not (my/prog-phscroll--eligible-p)))
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/notes.org")
    (should-not (my/prog-phscroll--eligible-p))))

(ert-deftest my/prog-phscroll-maybe-enables-eligible-files ()
  "The single file hook only enables scrolling for eligible source files."
  (with-temp-buffer
    (emacs-lisp-mode)
    (let ((enabled 0))
      (cl-letf (((symbol-function 'my/prog-phscroll-mode)
                 (lambda (&rest _) (cl-incf enabled))))
        (my/prog-phscroll-maybe-enable)
        (should (= enabled 0))
        (setq buffer-file-name "/tmp/example.el")
        (my/prog-phscroll-maybe-enable)
        (should (= enabled 1))
        (text-mode)
        (my/prog-phscroll-maybe-enable)
        (should (= enabled 1))))))

(ert-deftest my/prog-phscroll-major-mode-change-cleans-hook ()
  "A mode change must not leave the previous source scroll mode active."
  (with-temp-buffer
    (setq-local my/prog-phscroll-mode t)
    (add-hook 'change-major-mode-hook
              #'my/prog-phscroll--before-major-mode-change nil t)
    (my/prog-phscroll--before-major-mode-change)
    (should-not my/prog-phscroll-mode)
    (should-not (memq #'my/prog-phscroll--before-major-mode-change
                      change-major-mode-hook))))

(provide 'my-prog-phscroll-test)
;;; my-prog-phscroll-test.el ends here
