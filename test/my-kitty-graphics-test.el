;;; my-kitty-graphics-test.el --- Tests for WezTerm Sixel workaround -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'my-kitty-graphics)

;; This variable is defined by kitty-graphics.el at runtime.  Declare it
;; special so these tests need no terminal or graphics package installed.
(defvar kitty-graphics--active-backend)

(ert-deftest my-kitty-graphics-sixel-delete-is-skipped-in-wezterm ()
  "Do not overwrite Org text by erasing stale Sixel coordinates."
  (let ((kitty-graphics--active-backend 'sixel)
        (original-called nil))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t)))
      (should-not
       (my/kitty-graphics-sixel-delete-safely
        (lambda (&rest _args) (setq original-called t))
        'overlay 123 456))
      (should-not original-called))))

(ert-deftest my-kitty-graphics-sixel-delete-works-in-other-terminals ()
  "Non-WezTerm Sixel behavior must remain unchanged."
  (let ((kitty-graphics--active-backend 'sixel)
        (args nil))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () nil)))
      (should (eq 'deleted
                  (my/kitty-graphics-sixel-delete-safely
                   (lambda (&rest xs)
                     (setq args xs)
                     'deleted)
                   'overlay 123 456)))
      (should (equal args '(overlay 123 456))))))

(ert-deftest my-kitty-graphics-deletion-works-for-kitty-backend ()
  "Even in WezTerm, non-Sixel backends retain normal deletion."
  (let ((kitty-graphics--active-backend 'kitty)
        (original-called nil))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t)))
      (should (eq 'deleted
                  (my/kitty-graphics-sixel-delete-safely
                   (lambda (&rest _args)
                     (setq original-called t)
                     'deleted))))
      (should original-called))))

(ert-deftest my-kitty-graphics-wezterm-detection ()
  "Detect WezTerm via either of its environment markers."
  (cl-letf (((symbol-function 'getenv)
             (lambda (name)
               (pcase name
                 ("WEZTERM_PANE" "pane-1")
                 (_ nil)))))
    (should (my/kitty-graphics-wezterm-p)))
  (cl-letf (((symbol-function 'getenv)
             (lambda (name)
               (when (equal name "TERM_PROGRAM") "WezTerm"))))
    (should (my/kitty-graphics-wezterm-p)))
  (cl-letf (((symbol-function 'getenv)
             (lambda (_name) nil)))
    (should-not (my/kitty-graphics-wezterm-p))))

;;; my-kitty-graphics-test.el ends here
