;;; my-markdown.el --- Markdown reading and editing -*- lexical-binding: t; -*-

;;; Commentary:
;; 閲覧中は装飾を固定し、編集時はMarkdownの元の記法を表示する。

;;; Code:

;; 読み込み前から呼べるよう、遅延読み込みする関数・変数を宣言する。
(defvar markdown-ts-hide-markup)
(defvar markdown-ts-appear-mode)
(defvar markdown-indent-mode)
(declare-function markdown-ts-appear-mode "markdown-ts-appear" (&optional arg))
(declare-function markdown-ts-appear-stop "markdown-ts-appear" ())
(declare-function markdown-indent-mode "markdown-indent-mode" (&optional arg))
(declare-function markdown-ts-toggle-hide-markup "markdown-ts-mode" ())

(defvar-local my/markdown--reading nil
  "Non-nil when the Markdown buffer is in reading mode.")

(defvar-local my/markdown--saved-read-only nil
  "Read-only state before entering Markdown reading mode.")

(defvar my/markdown-reading-max-width 115
  "Maximum reading text width in terminal columns.")

(defvar-local my/markdown--saved-visual-line-mode nil
  "Whether `visual-line-mode' was enabled before reading mode.")

(defvar my/markdown--updating-margins nil
  "Non-nil while recalculating reading margins.")

(defun my/markdown--center-margins (width)
  "Return centered (LEFT . RIGHT) margins for WIDTH columns."
  (let* ((extra (max 0 (- width my/markdown-reading-max-width)))
         (left (/ extra 2)))
    (cons left (- extra left))))

(defun my/markdown--normalized-margins (margins)
  "Return MARGINS with missing sides converted to zero."
  (cons (or (car margins) 0) (or (cdr margins) 0)))

(defun my/markdown--update-window (window)
  "Center Markdown reading text in WINDOW, restoring margins otherwise."
  (when (window-live-p window)
    (let* ((reading (buffer-local-value
                     'my/markdown--reading (window-buffer window)))
           (saved (window-parameter window 'my/markdown--layout)))
      (cond
       (reading
        ;; Margins are window-local: save them before changing the layout.
        (unless saved
          (setq saved (list :margins (window-margins window)
                            :min-margins (window-parameter window 'min-margins)))
          (set-window-parameter window 'my/markdown--layout saved)
          ;; Large margins must not prevent normal window splitting.
          (set-window-parameter window 'min-margins '(0 . 0)))
        (let* ((current (my/markdown--normalized-margins
                         (window-margins window)))
               ;; Add back existing margins so repeated calls are stable.
               (available (+ (window-body-width window)
                             (car current) (cdr current)))
               (desired (my/markdown--center-margins available)))
          (unless (equal current desired)
            (set-window-margins window (car desired) (cdr desired)))
          (set-window-parameter
           window 'my/markdown--layout
           (plist-put saved :applied
                      (my/markdown--normalized-margins
                       (window-margins window))))))
       (saved
        (set-window-parameter window 'my/markdown--layout nil)
        (set-window-parameter window 'min-margins
                              (plist-get saved :min-margins))
        ;; A newly displayed buffer might have chosen its own margins.
        (when (equal (my/markdown--normalized-margins (window-margins window))
                     (plist-get saved :applied))
          (let ((original (plist-get saved :margins)))
            (set-window-margins window (car original) (cdr original)))))))))

(defun my/markdown--refresh-frame (frame)
  "Update Markdown reading layouts in FRAME."
  (unless my/markdown--updating-margins
    (let ((my/markdown--updating-margins t))
      (walk-windows #'my/markdown--update-window nil frame))))

(defun my/markdown--refresh-windows ()
  "Update reading layouts in all frames."
  (dolist (frame (frame-list))
    (my/markdown--refresh-frame frame)))

(defun my/markdown--watch-windows ()
  "Recenter reading text when windows change size or buffer."
  (add-hook 'window-size-change-functions #'my/markdown--refresh-frame)
  (add-hook 'window-buffer-change-functions #'my/markdown--refresh-frame))

(defun my/markdown-enable-reading ()
  "Enable fixed, read-only Markdown rendering in the current buffer."
  (unless my/markdown--reading
    (setq-local my/markdown--saved-read-only buffer-read-only
                my/markdown--saved-visual-line-mode
                (bound-and-true-p visual-line-mode))
    ;; 見出しの字下げ、コード枠、表などの装飾は残す。
    (unless (bound-and-true-p markdown-indent-mode)
      (markdown-indent-mode 1))
    (unless (bound-and-true-p markdown-ts-appear-mode)
      (markdown-ts-appear-mode 1))
    ;; カーソル位置で記号を再表示する追跡処理だけ止める。
    (markdown-ts-appear-stop)
    (read-only-mode 1)
    (visual-line-mode 1)
    (setq-local my/markdown--reading t)
    (my/markdown--watch-windows)
    (my/markdown--refresh-windows)))

(defun my/markdown--enable-editing ()
  "Show unadorned Markdown source in the current buffer."
  (when my/markdown--reading
    (let ((inhibit-read-only t))
      (markdown-ts-appear-mode -1)
      (markdown-indent-mode -1)
      ;; appearを止めるとhide-markupが既定値へ戻るため、明示的に解除。
      (when markdown-ts-hide-markup
        (markdown-ts-toggle-hide-markup)))
    ;; 元から読み取り専用だったバッファは編集可能にしない。
    (read-only-mode (if my/markdown--saved-read-only 1 -1))
    (visual-line-mode (if my/markdown--saved-visual-line-mode 1 -1))
    (setq-local my/markdown--reading nil)
    (my/markdown--refresh-windows)))

(defun my/markdown-toggle-mode ()
  "Toggle fixed reading and source editing in a Markdown TS buffer.
Reading is read-only; editing shows Markdown markup and preserves an
originally read-only buffer's protection."
  (interactive)
  (unless (derived-mode-p 'markdown-ts-mode)
    (user-error "Not a Markdown TS buffer"))
  (if my/markdown--reading
      (my/markdown--enable-editing)
    (my/markdown-enable-reading))
  (message "Markdown: %s" (if my/markdown--reading "reading" "editing")))

(provide 'my-markdown)

;;; my-markdown.el ends here
