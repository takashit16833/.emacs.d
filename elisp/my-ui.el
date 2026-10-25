;;; my-ui.el --- Shared UI helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 見た目の設定関数をまとめる。

;;; Code:

(require 'cl-lib)
(require 'disp-table)

(defvar nerd-icons-color-icons)
(declare-function nerd-icons-icon-for-file "nerd-icons" (file &rest options))

;;; Nerd Font

(defvar-local my/file-icon-cache nil
  "現在のバッファのファイルアイコンをキャッシュする。")


(defun my/file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (when buffer-file-name
    (if (equal (car-safe my/file-icon-cache)
               buffer-file-name)
        (cdr my/file-icon-cache)
      ;; ファイル種別ごとの色を使わず、表示先の文字色を継承する。
      (let* ((nerd-icons-color-icons nil)
             (icon (nerd-icons-icon-for-file buffer-file-name)))
        (setq my/file-icon-cache
              (cons buffer-file-name icon))
        icon))))


;;; Line numbers

(defun my/display-line-numbers-for-text ()
  "Enable line numbers in text buffers other than Org and Markdown."
  (unless (derived-mode-p 'org-mode 'markdown-ts-mode)
    (display-line-numbers-mode 1)))


;;; Window borders

(defvar display-line-numbers-mode)

(defun my/vertical-border--right-neighbor-p (left right)
  "Return non-nil if RIGHT touches the right edge of LEFT."
  (let ((a (window-edges left))
        (b (window-edges right)))
    (and (not (eq left right))
         (= (nth 2 a) (car b))
         (< (nth 1 a) (nth 3 b))
         (< (nth 1 b) (nth 3 a)))))


(defun my/vertical-border--glyph (window windows)
  "Return the border character for WINDOW given WINDOWS in its frame.
The right window's line-number gutter acts as the separator.  If
any adjacent right window has no line numbers, draw the border."
  (if (cl-some
       (lambda (right)
         (and (my/vertical-border--right-neighbor-p window right)
              (not (with-current-buffer (window-buffer right)
                     (bound-and-true-p display-line-numbers-mode)))))
       windows)
      ?│
    ?\s))


(defun my/vertical-border--update-window (window windows)
  "Update WINDOW's border using WINDOWS without changing buffer tables."
  (let* ((buffer (window-buffer window))
         (source (or (buffer-local-value 'buffer-display-table buffer)
                     standard-display-table))
         (current (window-display-table window))
         ;; Track our own table to avoid reusing it after a buffer switch.
         ;; An unrelated window display table takes precedence as the base.
         (owned (window-parameter window 'my/vertical-border))
         (glyph (my/vertical-border--glyph window windows)))
    (unless (and (eq (nth 0 owned) buffer)
                 (eq (nth 1 owned) source)
                 (eq (nth 2 owned) current)
                 (eq (display-table-slot current 'vertical-border) glyph))
      (let* ((base (if (eq current (nth 2 owned))
                       source
                     (or current source)))
             (table (copy-sequence (or base (make-display-table)))))
        (set-display-table-slot table 'vertical-border glyph)
        (set-window-display-table window table)
        (set-window-parameter window 'my/vertical-border
                              (list buffer source table))))))


(defun my/update-vertical-borders (&optional frame)
  "Update vertical borders in FRAME based on right-neighbor line numbers.
Designed for the default value of `window-state-change-functions'."
  (setq frame (or frame (selected-frame)))
  (when (and (frame-live-p frame)
             (not (display-graphic-p frame)))
    (let ((windows (window-list frame 'no-minibuffer)))
      (dolist (window windows)
        (my/vertical-border--update-window window windows)))))


(defun my/update-vertical-borders-for-buffer ()
  "Update visible frames when the current buffer toggles line numbers."
  (dolist (frame (frame-list))
    (when (get-buffer-window (current-buffer) frame)
      (my/update-vertical-borders frame))))

;;; Mood-line

(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (my/file-icon))


;;; Corfu

(defun my/corfu-offset-tty-popup (original frame x y width height)
  "TTYのCorfu候補を右へ1文字、下へ1行ずらす。"
  (if (and (not (display-graphic-p))
           (string= (buffer-name) " *corfu*"))
      (funcall original
               frame
               (+ x (default-font-width))
               (+ y (default-line-height))
               width
               height)
    (funcall original frame x y width height)))


(provide 'my-ui)


;;; my-ui.el ends here
