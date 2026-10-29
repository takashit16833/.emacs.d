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

(ert-deftest my/prog-phscroll-only-enables-for-files ()
  "Avoid changing scratch and other temporary program buffers."
  (with-temp-buffer
    (let ((enabled 0))
      (cl-letf (((symbol-function 'my/prog-phscroll-mode)
                 (lambda (&rest _) (cl-incf enabled))))
        (my/prog-phscroll-maybe-enable)
        (should (= enabled 0))
        (setq buffer-file-name "/tmp/example.py")
        (my/prog-phscroll-maybe-enable)
        (should (= enabled 1))))))

(provide 'my-prog-phscroll-test)
;;; my-prog-phscroll-test.el ends here
