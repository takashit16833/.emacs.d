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

(declare-function my/prog-phscroll-mode "my-prog-phscroll" (&optional arg))

(defun my/prog-phscroll--before-major-mode-change ()
  "Remove the old scroll overlays before this buffer changes major mode."
  (my/prog-phscroll-mode -1))

(defun my/prog-phscroll--eligible-p ()
  "Return non-nil for files that should use whole-buffer scrolling.
Most programming languages inherit from prog-mode.  YAML in Emacs 31
inherits from text-mode (and yaml-mode), so include that family.
This decision lives here; no mode-specific hook registrations are needed."
  (and buffer-file-name
       (or (derived-mode-p 'prog-mode)
           (derived-mode-p 'yaml-mode))))

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
        (add-hook 'change-major-mode-hook
                  #'my/prog-phscroll--before-major-mode-change nil t)
        (my/prog-phscroll--sync))
    (remove-hook 'after-change-functions #'my/prog-phscroll--sync t)
    (remove-hook 'change-major-mode-hook
                 #'my/prog-phscroll--before-major-mode-change t)
    (when (featurep 'phscroll)
      (phscroll-delete-all)
      (phscroll-mode -1))
    (setq my/prog-phscroll--area nil)))

(defun my/prog-phscroll-maybe-enable ()
  "Enable whole-buffer scrolling when visiting an eligible source file."
  (when (my/prog-phscroll--eligible-p)
    (my/prog-phscroll-mode 1)))

(provide 'my-prog-phscroll)
;;; my-prog-phscroll.el ends here
