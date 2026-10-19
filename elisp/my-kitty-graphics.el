;;; my-kitty-graphics.el --- Workarounds for terminal image rendering -*- lexical-binding: t; -*-
;;; Commentary:
;; WezTerm's Sixel rendering works for scrolling, but kitty-graphics.el
;; removes old image placements by writing spaces to their former screen
;; coordinates.  Those writes can erase unrelated Org text after a scroll.
;; Prefer occasional image ghosts over deleting actual text on screen.
;;; Code:

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

(provide 'my-kitty-graphics)
;;; my-kitty-graphics.el ends here
