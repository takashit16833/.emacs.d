;;; my-centered-text.el --- Center buffer text within a window -*- lexical-binding: t; -*-

;;; Commentary:
;; Limit text width without changing buffer contents.
;; Window margins must be restored when another buffer is displayed.

;;; Code:

(defvar my/centered-text-max-width 115
  "Maximum centered text width in terminal columns.")

(defvar my/centered-text--updating-margins nil
  "Non-nil while recalculating reading margins.")

(defun my/centered-text--center-margins (width)
  "Return centered (LEFT . RIGHT) margins for WIDTH columns."
  (let* ((extra (max 0 (- width my/centered-text-max-width)))
         (left (/ extra 2)))
    (cons left (- extra left))))

(defun my/centered-text--normalized-margins (margins)
  "Return MARGINS with missing sides converted to zero."
  (cons (or (car margins) 0) (or (cdr margins) 0)))

(defun my/centered-text--update-window (window)
  "Center text in WINDOW if enabled, restoring margins otherwise."
  (when (window-live-p window)
    (let* ((reading (buffer-local-value
                     'my/centered-text-mode (window-buffer window)))
           (saved (window-parameter window 'my/centered-text--layout)))
      (cond
       (reading
        ;; Margins are window-local: save them before changing the layout.
        (unless saved
          (setq saved (list :margins (window-margins window)
                            :min-margins (window-parameter window 'min-margins)))
          (set-window-parameter window 'my/centered-text--layout saved)
          ;; Large margins must not prevent normal window splitting.
          (set-window-parameter window 'min-margins '(0 . 0)))
        (let* ((current (my/centered-text--normalized-margins
                         (window-margins window)))
               ;; Add back existing margins so repeated calls are stable.
               (available (+ (window-body-width window)
                             (car current) (cdr current)))
               (desired (my/centered-text--center-margins available)))
          (unless (equal current desired)
            (set-window-margins window (car desired) (cdr desired)))
          (set-window-parameter
           window 'my/centered-text--layout
           (plist-put saved :applied
                      (my/centered-text--normalized-margins
                       (window-margins window))))))
       (saved
        (set-window-parameter window 'my/centered-text--layout nil)
        (set-window-parameter window 'min-margins
                              (plist-get saved :min-margins))
        ;; A newly displayed buffer might have chosen its own margins.
        (when (equal (my/centered-text--normalized-margins (window-margins window))
                     (plist-get saved :applied))
          (let ((original (plist-get saved :margins)))
            (set-window-margins window (car original) (cdr original)))))))))

(defun my/centered-text--refresh-frame (frame)
  "Update centered text layouts in FRAME."
  (unless my/centered-text--updating-margins
    (let ((my/centered-text--updating-margins t))
      (walk-windows #'my/centered-text--update-window nil frame))))

(defun my/centered-text--refresh-windows ()
  "Update centered text layouts in all frames."
  (dolist (frame (frame-list))
    (my/centered-text--refresh-frame frame)))

(defun my/centered-text--watch-windows ()
  "Recenter text when windows change size or buffer."
  (add-hook 'window-size-change-functions #'my/centered-text--refresh-frame)
  (add-hook 'window-buffer-change-functions #'my/centered-text--refresh-frame))

(define-minor-mode my/centered-text-mode
  "Center this buffer's text up to `my/centered-text-max-width' columns.
Preserve existing window margins when switching to another buffer."
  :init-value nil
  :lighter nil
  (when my/centered-text-mode
    (my/centered-text--watch-windows))
  (my/centered-text--refresh-windows))

(provide 'my-centered-text)
;;; my-centered-text.el ends here
