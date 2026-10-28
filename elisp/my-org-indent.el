;;; my-org-indent.el --- Org source block wrap backgrounds -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep the source-block background on virtual indentation at wrapped lines.
;; The normal line prefix and the window's wrap indicator are untouched.

;;; Code:

(declare-function org-in-src-block-p "org" (&optional inside element))

;; Dynamically bound while org-indent computes a range of lines.
(defvar my/org-indent--tracking nil)
(defvar my/org-indent--inside-src nil)
(defvar my/org-indent--block-background nil)

(defun my/org-indent--source-background ()
  "Return the current Org source block background."
  (face-background 'org-block nil t))

(defun my/org-indent--around-add-properties (original beg end &optional delay)
  "Track source block boundaries while ORIGINAL indents BEG to END.
Pass DELAY through unchanged so Org's incremental updates still work."
  ;; The range may start in the middle of a source block.  Parse once
  ;; here rather than calling `org-element-at-point' for every line.
  (let ((my/org-indent--tracking t)
        (my/org-indent--inside-src
         (save-excursion
           (goto-char beg)
           (beginning-of-line)
           (org-in-src-block-p t)))
        (my/org-indent--block-background (my/org-indent--source-background)))
    (funcall original beg end delay)))

(defun my/org-indent--color-wrap-prefix (beg)
  "Color the virtual wrap indentation of the source line at BEG."
  (when (stringp my/org-indent--block-background)
    (let ((prefix (get-text-property beg 'wrap-prefix)))
      (when (and (stringp prefix) (> (length prefix) 0))
        ;; Org reuses prefix strings.  Never alter the shared string, and
        ;; leave `line-prefix' alone to avoid coloring the normal margin.
        (let ((colored (copy-sequence prefix)))
          (put-text-property
           0 (length colored) 'face
           `(:inherit org-indent :background ,my/org-indent--block-background)
           colored)
          (with-silent-modifications
            (put-text-property beg (save-excursion
                                     (goto-char beg)
                                     (line-beginning-position 2))
                               'wrap-prefix colored)))))))

(defun my/org-indent--around-set-line-properties (original &rest args)
  "Preserve source background after ORIGINAL sets line indentation."
  (if (not my/org-indent--tracking)
      (apply original args)
    (let* ((beg (line-beginning-position))
           (case-fold-search t)
           (close (and my/org-indent--inside-src
                       (looking-at-p "[ \t]*#\\+end_src\\(?:[ \t]\\|$\\)")))
           (open (and (not my/org-indent--inside-src)
                      (looking-at-p "[ \t]*#\\+begin_src\\(?:[ \t]\\|$\\)")
                      (org-in-src-block-p)))
           (content (and my/org-indent--inside-src (not close))))
      (prog1 (apply original args)
        (when content
          (my/org-indent--color-wrap-prefix beg))
        (cond (close (setq my/org-indent--inside-src nil))
              (open (setq my/org-indent--inside-src t)))))))

(with-eval-after-load 'org-indent
  (unless (advice-member-p #'my/org-indent--around-add-properties
                           'org-indent-add-properties)
    (advice-add 'org-indent-add-properties :around
                #'my/org-indent--around-add-properties))
  (unless (advice-member-p #'my/org-indent--around-set-line-properties
                           'org-indent-set-line-properties)
    (advice-add 'org-indent-set-line-properties :around
                #'my/org-indent--around-set-line-properties)))

(provide 'my-org-indent)

;;; my-org-indent.el ends here
