;;; my-prog-phscroll.el --- Horizontal scrolling for program buffers -*- lexical-binding: t; -*-

;;; Commentary:
;; The manually tested phscroll behavior applies to ordinary source files too.
;; Treat the entire program buffer as one scrollable region.  Unlike the Org
;; integration, no column width compensation is needed.  Preserve the source
;; text and keep the default (non-character) overflow indicator.

;;; Code:

(declare-function phscroll-mode "phscroll" (&optional arg))
(declare-function phscroll-region "phscroll" (beg end))
(declare-function phscroll-delete-all "phscroll" ())
(declare-function phscroll-area-begin "phscroll" (&optional area))
(declare-function phscroll-area-end "phscroll" (&optional area))

(defvar phscroll-use-fringe)
(defvar-local my/prog-phscroll-mode nil)
(defvar-local my/prog-phscroll--area nil)

(defun my/prog-phscroll--sync (&rest _)
  "Keep the horizontal scroll region aligned with the buffer.
Called after edits.  Reuse unchanged areas to preserve the scroll position."
  (when my/prog-phscroll-mode
    (let ((beg (point-min))
          (end (point-max)))
      (cond
       ((= beg end)
        (when my/prog-phscroll--area
          (phscroll-delete-all)
          (setq my/prog-phscroll--area nil)))
       ((not (and my/prog-phscroll--area
                  (equal (phscroll-area-begin my/prog-phscroll--area) beg)
                  (equal (phscroll-area-end my/prog-phscroll--area) end)))
        (setq my/prog-phscroll--area (phscroll-region beg end)))))))

(define-minor-mode my/prog-phscroll-mode
  "Prevent wrapping in program source buffers using phscroll."
  :init-value nil
  :lighter nil
  (if my/prog-phscroll-mode
      (progn
        (require 'phscroll)
        ;; Do not display < or > overflow characters in terminal Emacs.
        (setq-local phscroll-use-fringe t)
        (phscroll-mode 1)
        (add-hook 'after-change-functions #'my/prog-phscroll--sync nil t)
        (my/prog-phscroll--sync))
    (remove-hook 'after-change-functions #'my/prog-phscroll--sync t)
    (when (featurep 'phscroll)
      (phscroll-delete-all)
      (phscroll-mode -1))
    (setq my/prog-phscroll--area nil)))

(defun my/prog-phscroll-maybe-enable ()
  "Use horizontal scrolling only in source files, not temporary buffers."
  (when buffer-file-name
    (my/prog-phscroll-mode 1)))

(provide 'my-prog-phscroll)
;;; my-prog-phscroll.el ends here
