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
        (let ((size (format "%dx%d" cols rows)))
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
       (format "kitty-graphics-chafa-v1-%s.six"
               (md5 (format "%s:%dx%d" file cols rows)))
       temporary-file-directory)
    (funcall original file cols rows)))

(provide 'my-kitty-graphics)
;;; my-kitty-graphics.el ends here
