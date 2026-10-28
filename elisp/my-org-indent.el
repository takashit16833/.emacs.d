;;; my-org-indent.el --- Org block wrap backgrounds -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep the source/example block background on virtual wrapped indentation.
;; The normal line prefix and the window's wrap indicator are untouched.

;;; Code:

(declare-function org-element-at-point "org-element" (&optional epom cached-only))
(declare-function org-element-type "org-element-ast" (node &optional anonymous))
(declare-function org-element-post-affiliated "org-element" (node))

;; Dynamically bound while org-indent computes a range of lines.
(defvar my/org-indent--tracking nil)
(defvar my/org-indent--inside-block nil)
(defvar my/org-indent--block-background nil)

(defun my/org-indent--source-background ()
  "Return the background shared by Org source and example blocks."
  (face-background 'org-block nil t))

(defun my/org-indent--content-block-at-point ()
  "Return the type of the source or example block containing this line.
The block delimiter lines themselves are not considered content."
  (let* ((element (org-element-at-point))
         (type (org-element-type element))
         (case-fold-search t))
    (when (and (memq type '(src-block example-block))
               (> (line-beginning-position)
                  (org-element-post-affiliated element))
               (not (looking-at-p
                     (if (eq type 'src-block)
                         "[ \t]*#\\+end_src[ \t]*$"
                       "[ \t]*#\\+end_example[ \t]*$"))))
      type)))

(defun my/org-indent--around-add-properties (original beg end &optional delay)
  "Track source/example blocks while ORIGINAL indents BEG to END.
Pass DELAY through unchanged so Org's incremental updates still work."
  ;; A refresh may start within a block.  Parse that position only once,
  ;; then track opening/closing lines instead of parsing every source line.
  (let ((my/org-indent--tracking t)
        (my/org-indent--inside-block
         (save-excursion
           (goto-char beg)
           (beginning-of-line)
           (my/org-indent--content-block-at-point)))
        (my/org-indent--block-background (my/org-indent--source-background)))
    (funcall original beg end delay)))

(defun my/org-indent--color-wrap-prefix (beg)
  "Color the virtual wrap indentation of the block line at BEG."
  (when (stringp my/org-indent--block-background)
    (let ((line (get-text-property beg 'line-prefix))
          (prefix (get-text-property beg 'wrap-prefix)))
      (when (and (stringp line) (stringp prefix)
                 (< (length line) (length prefix)))
        ;; The wrap prefix starts with the same virtual heading indent as
        ;; the line prefix.  Keep that part untouched; it is outside the
        ;; source block's background.  Color only the extra code indent.
        (let ((colored (copy-sequence prefix)))
          (put-text-property
           (length line) (length colored) 'face
           `(:inherit org-indent :background ,my/org-indent--block-background)
           colored)
          (with-silent-modifications
            (put-text-property beg (save-excursion
                                     (goto-char beg)
                                     (line-beginning-position 2))
                               'wrap-prefix colored)))))))

(defun my/org-indent--around-set-line-properties (original &rest args)
  "Preserve block background after ORIGINAL sets line indentation."
  (if (not my/org-indent--tracking)
      (apply original args)
    (let* ((beg (line-beginning-position))
           (case-fold-search t)
           (type my/org-indent--inside-block)
           (close (and type
                       (looking-at-p
                        (if (eq type 'src-block)
                            "[ \t]*#\\+end_src[ \t]*$"
                          "[ \t]*#\\+end_example[ \t]*$"))))
           (open-type
            (unless type
              (cond
               ((and (looking-at-p "[ \t]*#\\+begin_src\\(?:[ \t]\\|$\\)")
                     (eq (org-element-type (org-element-at-point)) 'src-block))
                'src-block)
               ((and (looking-at-p "[ \t]*#\\+begin_example\\(?:[ \t]\\|$\\)")
                     (eq (org-element-type (org-element-at-point)) 'example-block))
                'example-block))))
           (content (and type (not close))))
      (prog1 (apply original args)
        (when content
          (my/org-indent--color-wrap-prefix beg))
        (cond (close (setq my/org-indent--inside-block nil))
              (open-type (setq my/org-indent--inside-block open-type)))))))

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
