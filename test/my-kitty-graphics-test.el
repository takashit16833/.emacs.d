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

(ert-deftest my-kitty-graphics-chafa-extracts-only-sixel ()
  "Strip terminal-side cursor control while retaining transparent Sixel."
  (should (equal
           (my/kitty-graphics--chafa-sixel-data
            (concat "prefix\n" "\eP0;1;0q" "data" "\e\\" "\n"))
           (concat "\eP0;1;0q" "data" "\e\\")))
  (should-not (my/kitty-graphics--chafa-sixel-data "no sixel")))

(ert-deftest my-kitty-graphics-chafa-encodes-wezterm-sixel ()
  "Run Chafa with explicit size and return one raw Sixel sequence."
  (let ((kitty-graphics--active-backend 'sixel)
        (kitty-graphics-sixel-encoder-timeout 5.0)
        (recorded nil)
        (called-original nil))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t))
              ((symbol-function 'executable-find)
               (lambda (binary)
                 (when (equal binary "chafa") "/opt/homebrew/bin/chafa")))
              ((symbol-function 'kitty-graphics--sixel-run-encoder)
               (lambda (program timeout destination args)
                 (setq recorded (list program timeout args))
                 (should (eq destination (current-buffer)))
                 (insert (concat "before\n" "\eP0;1;0q" "SIXEL" "\e\\" "\n"))
                 t)))
      (should (equal
               (my/kitty-graphics-sixel-encode-with-chafa
                (lambda (&rest _) (setq called-original t))
                "/some/diagram.png" 50 30)
               (concat "\eP0;1;0q" "SIXEL" "\e\\")))
      (should-not called-original)
      (should (equal (nth 0 recorded) "/opt/homebrew/bin/chafa"))
      (should (member "--stretch" (nth 2 recorded)))
      (should (member "50x30" (nth 2 recorded)))
      (should (equal (car (last (nth 2 recorded))) "/some/diagram.png")))))

(ert-deftest my-kitty-graphics-chafa-leaves-kitty-backend-unchanged ()
  "Never switch non-Sixel renderers even in WezTerm."
  (let ((kitty-graphics--active-backend 'kitty)
        (original-called nil))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t))
              ((symbol-function 'executable-find)
               (lambda (_binary) "/opt/homebrew/bin/chafa")))
      (should (equal
               (my/kitty-graphics-sixel-encode-with-chafa
                (lambda (&rest _args)
                  (setq original-called t)
                  "original sixel")
                "image.png" 10 10)
               "original sixel"))
      (should original-called))))

(ert-deftest my-kitty-graphics-chafa-falls-back-when-missing ()
  "Preserve the upstream encoder if Chafa is not installed."
  (let ((kitty-graphics--active-backend 'sixel))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t))
              ((symbol-function 'executable-find)
               (lambda (_binary) nil)))
      (should (equal
               (my/kitty-graphics-sixel-encode-with-chafa
                (lambda (&rest _args) "upstream")
                "image.png" 10 10)
               "upstream")))))

(ert-deftest my-kitty-graphics-chafa-isolates-sixel-cache ()
  "Chafa must not reuse a Sixel file encoded by img2sixel."
  (let ((kitty-graphics--active-backend 'sixel))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t))
              ((symbol-function 'executable-find)
               (lambda (program)
                 (when (equal program "chafa") "/opt/homebrew/bin/chafa"))))
      (let ((result (my/kitty-graphics-sixel-cache-path-with-chafa
                     (lambda (&rest _) "old.six") "image.png" 30 20)))
        (should (string-match-p "kitty-graphics-chafa-v1-" result))
        (should-not (equal result "old.six"))
        (should (equal result
                       (my/kitty-graphics-sixel-cache-path-with-chafa
                        (lambda (&rest _) "old.six") "image.png" 30 20))))))
  (let ((kitty-graphics--active-backend 'kitty))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t)))
      (should (equal
               (my/kitty-graphics-sixel-cache-path-with-chafa
                (lambda (&rest _) "old.six") "image.png" 30 20)
               "old.six")))))

;;; my-kitty-graphics-test.el ends here
