;;; my-org-phscroll.el --- Horizontal scrolling for Org tables and blocks -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep Org tables and source/example blocks editable while scrolling them
;; horizontally.  Unlike org-phscroll-mode, manage both kinds of regions
;; together: org-phscroll-mode removes scrolling regions outside tables.
;; The original Org text is never changed.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-element)
(require 'org-table)

;; phscroll is loaded at runtime by the minor mode.  Declare its API here so
;; byte compilation with byte-compile-error-on-warn does not depend on
;; whichever functions the installed package happens to autoload.
(declare-function phscroll-area-begin "phscroll" (&optional area))
(declare-function phscroll-area-end "phscroll" (&optional area))
(declare-function phscroll-area-destroy "phscroll" (area))
(declare-function phscroll-enum-area "phscroll" (&optional beg end))
(declare-function phscroll-region "phscroll" (beg end))
(declare-function phscroll-mode "phscroll" (&optional arg))
(declare-function phscroll-delete-all "phscroll" ())

(defvar-local my/org-phscroll-mode nil)
(defvar-local my/org-phscroll--refresh-timer nil)

(defun my/org-phscroll--before-major-mode-change ()
  "Remove Org scroll areas before changing to another major mode."
  (my/org-phscroll-mode -1))

(defun my/org-phscroll--window-width (original pos window)
  "Use the visible line prefix, not the wrap prefix, for Org scrolling.
ORIGINAL is phscroll-window-width-at; POS and WINDOW are its arguments.
org-indent-mode can give a source line a much longer wrap-prefix than
line-prefix.  Phscroll normally subtracts wrap-prefix, hiding usable space."
  (let ((width (funcall original pos window)))
    (if (and my/org-phscroll-mode
             (derived-mode-p 'org-mode)
             (integer-or-marker-p pos))
        (max 0 (+ width
                  (- (length (get-text-property pos 'wrap-prefix))
                     (length (get-text-property pos 'line-prefix)))))
      width)))

(defun my/org-phscroll--block-region (element)
  "Return the content range of source/example block ELEMENT.
Unlike container elements, these block types have no :contents-begin
or :contents-end properties.  Find the closing delimiter instead.
Exclude both delimiters and any affiliated #+NAME or #+CAPTION lines."
  (save-excursion
    (goto-char (org-element-property :post-affiliated element))
    (forward-line 1)
    (let ((beg (point))
          (case-fold-search t)
          (closing (if (eq (org-element-type element) 'src-block)
                       "^[[:blank:]]*#\\+end_src[[:blank:]]*$"
                     "^[[:blank:]]*#\\+end_example[[:blank:]]*$")))
      (when (re-search-forward closing (org-element-property :end element) t)
        (let ((end (line-beginning-position)))
          (when (< beg end)
            (cons beg end)))))))

(defun my/org-phscroll--regions ()
  "Return the (BEG . END) ranges to scroll in this Org buffer.
Include Org pipe tables and the contents of source/example blocks.
Do not include block delimiter lines or text that only resembles a table."
  (delq nil
        (org-element-map (org-element-parse-buffer)
            '(table src-block example-block)
          (lambda (element)
            (pcase (org-element-type element)
              ('table
               (when (eq (org-element-property :type element) 'org)
                 (save-excursion
                   (goto-char (org-element-property :begin element))
                   (cons (org-table-begin) (org-table-end)))))
              ((or 'src-block 'example-block)
               (my/org-phscroll--block-region element)))))))

(defun my/org-phscroll--area-bounds (area)
  "Return the buffer bounds of phscroll AREA."
  (cons (phscroll-area-begin area) (phscroll-area-end area)))

(defun my/org-phscroll-refresh ()
  "Synchronize the Org table/block scroll regions without resetting others.
Keep an existing area (and its horizontal position) when its bounds match."
  (interactive)
  (when my/org-phscroll-mode
    (save-excursion
      (let ((wanted (my/org-phscroll--regions)))
        (dolist (region wanted)
          (unless (member region
                          (mapcar #'my/org-phscroll--area-bounds
                                  (phscroll-enum-area)))
            ;; phscroll-region reuses an overlapping area when possible.
            (phscroll-region (car region) (cdr region))))
        (dolist (area (phscroll-enum-area))
          (unless (member (my/org-phscroll--area-bounds area) wanted)
            (phscroll-area-destroy area)))))))

(defun my/org-phscroll--refresh-buffer (buffer)
  "Refresh BUFFER if it is still a live Org buffer using this mode."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq my/org-phscroll--refresh-timer nil)
      (when my/org-phscroll-mode
        (my/org-phscroll-refresh)))))

(defun my/org-phscroll--schedule-refresh (&rest _)
  "Coalesce edits before updating Org table/block boundaries."
  (when (timerp my/org-phscroll--refresh-timer)
    (cancel-timer my/org-phscroll--refresh-timer))
  (setq my/org-phscroll--refresh-timer
        (run-with-idle-timer 0.3 nil
                             #'my/org-phscroll--refresh-buffer
                             (current-buffer))))

(define-minor-mode my/org-phscroll-mode
  "Horizontally scroll Org tables and source/example blocks."
  :init-value nil
  :lighter nil
  (if my/org-phscroll-mode
      (progn
        (require 'phscroll)
        (unless (advice-member-p #'my/org-phscroll--window-width
                                 'phscroll-window-width-at)
          (advice-add 'phscroll-window-width-at :around
                      #'my/org-phscroll--window-width))
        ;; On terminal Emacs, the fringe setting avoids visible < and >.
        (setq-local phscroll-use-fringe t)
        (phscroll-mode 1)
        (add-hook 'after-change-functions
                  #'my/org-phscroll--schedule-refresh nil t)
        (add-hook 'change-major-mode-hook
                  #'my/org-phscroll--before-major-mode-change nil t)
        (my/org-phscroll--schedule-refresh))
    (remove-hook 'after-change-functions
                 #'my/org-phscroll--schedule-refresh t)
    (remove-hook 'change-major-mode-hook
                 #'my/org-phscroll--before-major-mode-change t)
    (when (timerp my/org-phscroll--refresh-timer)
      (cancel-timer my/org-phscroll--refresh-timer))
    (setq my/org-phscroll--refresh-timer nil)
    (when (featurep 'phscroll)
      (phscroll-delete-all)
      (phscroll-mode -1))))

(provide 'my-org-phscroll)
;;; my-org-phscroll.el ends here
