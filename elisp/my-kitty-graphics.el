;;; my-kitty-graphics.el --- Workarounds for terminal image rendering -*- lexical-binding: t; -*-
;;; Commentary:
;; WezTerm's Sixel rendering works for scrolling, but kitty-graphics.el
;; removes old image placements by writing spaces to their former screen
;; coordinates.  Those writes can erase unrelated Org text after a scroll.
;; Prefer occasional image ghosts over deleting actual text on screen.
;;; Code:

(require 'subr-x)

;; Declared by kitty-graphics.el.  The guard below also allows these
;; helpers to be unit-tested without loading a terminal backend.
(defvar kitty-graphics--active-backend)

(defun my/kitty-graphics-wezterm-p ()
  "Return non-nil when this Emacs session runs in WezTerm."
  (or (getenv "WEZTERM_PANE")
      (equal (getenv "TERM_PROGRAM") "WezTerm")))

(defun my/kitty-graphics-sixel-delete-safely (original &rest args)
  "Call ORIGINAL with ARGS except for Sixel deletion in WezTerm.

Skipping the destructive blank-cell erase preserves the surrounding
text.  The trade-off is that old Sixel images may remain on the screen
after scrolling, switching buffers, or changing window layouts.
Other backends and terminals retain the upstream deletion behavior."
  (unless (and (my/kitty-graphics-wezterm-p)
               (boundp 'kitty-graphics--active-backend)
               (eq kitty-graphics--active-backend 'sixel))
    (apply original args)))

;; WezTermはChafa経由だとPNGの透明部分を維持したSixelを描画できる。
;; Kittyなど他のバックエンドでは従来のエンコーダーを使う。
(defvar kitty-graphics-sixel-encoder-timeout)
(defvar kitty-graphics--cell-pixel-width)
(defvar kitty-graphics--cell-pixel-height)
(defvar kitty-graphics--target-terminal)

;; Chafa defaults to 10x20 pixels per cell without a terminal pixel-size probe.
;; Emacs may use a different (e.g. 16x32) cell size on a Retina display.
(defconst my/kitty-graphics--chafa-cell-width 10)
(defconst my/kitty-graphics--chafa-cell-height 20)

(defun my/kitty-graphics--effective-cell-size ()
  "Return pixel cell dimensions used by kitty-graphics for this terminal.
Prefer the dynamically bound values from the active rendering context,
then the per-terminal measurements, and finally upstream's 8x16 fallback.
Do not query the terminal during rendering: that may consume input."
  (let ((term (or kitty-graphics--target-terminal
                  (frame-terminal (selected-frame)))))
    (cons (or kitty-graphics--cell-pixel-width
              (terminal-parameter term 'kitty-graphics-cell-w)
              8)
          (or kitty-graphics--cell-pixel-height
              (terminal-parameter term 'kitty-graphics-cell-h)
              16))))

(defun my/kitty-graphics--chafa-output-size (cols rows)
  "Compute Chafa cell extent matching COLS x ROWS actual terminal cells.
Chafa uses 10x20 virtual pixel cells when run without terminal probing,
so convert the allocated Emacs extent to an equivalent Chafa extent."
  (let ((actual (my/kitty-graphics--effective-cell-size)))
    (format "%dx%d"
            (max 1 (round (/ (* cols (car actual))
                             (float my/kitty-graphics--chafa-cell-width))))
            (max 1 (round (/ (* rows (cdr actual))
                             (float my/kitty-graphics--chafa-cell-height)))))))

(defun my/kitty-graphics--chafa-program ()
  "Return Chafa executable when WezTerm's Sixel backend should use it."
  (when (and (my/kitty-graphics-wezterm-p)
             (eq kitty-graphics--active-backend 'sixel))
    (executable-find "chafa")))

(defun my/kitty-graphics--chafa-sixel-data (output)
  "Extract one raw Sixel DCS from Chafa OUTPUT.
Discard its terminal setup codes and trailing newline so the caller's
existing cursor save, positioning, and restore remain authoritative."
  (let* ((start (string-match "\eP[0-9;]*q" output))
         (end (when start
                (string-match (regexp-quote (concat "\e" "\\"))
                              output (match-end 0)))))
    (when end
      (substring output start (+ end 2)))))

(defun my/kitty-graphics-sixel-encode-with-chafa (original png-file cols rows)
  "Encode PNG-FILE through Chafa in WezTerm; otherwise call ORIGINAL.
COLS and ROWS are the cell dimensions calculated by kitty-graphics.el.
Chafa is invoked without terminal probing and its output is restricted
to a single Sixel sequence to avoid moving the Emacs cursor."
  (if-let* ((chafa (my/kitty-graphics--chafa-program)))
      (with-temp-buffer
        (set-buffer-multibyte nil)
        (let ((size (my/kitty-graphics--chafa-output-size cols rows)))
          (when (kitty-graphics--sixel-run-encoder
                 chafa kitty-graphics-sixel-encoder-timeout (current-buffer)
                 (list "--format" "sixels"
                       "--probe" "off"
                       "--passthrough" "none"
                       "--relative" "on"
                       "--animate" "off"
                       "--exact-size" "off"
                       "--margin-bottom" "0"
                       "--size" size
                       "--view-size" size
                       "--stretch" png-file))
            (my/kitty-graphics--chafa-sixel-data (buffer-string)))))
    (funcall original png-file cols rows)))

(defun my/kitty-graphics-sixel-cache-path-with-chafa (original file cols rows)
  "Use a separate Sixel cache for Chafa, preserving ORIGINAL otherwise.
Previously generated img2sixel files must not mask Chafa's transparency."
  (if (my/kitty-graphics--chafa-program)
      (expand-file-name
       (format "kitty-graphics-chafa-v2-%s.six"
               (md5 (format "%s:%dx%d:%s" file cols rows
                            (my/kitty-graphics--effective-cell-size))))
       temporary-file-directory)
    (funcall original file cols rows)))

(provide 'my-kitty-graphics)
;;; my-kitty-graphics.el ends here
