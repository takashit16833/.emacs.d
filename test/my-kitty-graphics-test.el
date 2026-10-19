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
        (kitty-graphics--cell-pixel-width 16)
        (kitty-graphics--cell-pixel-height 32)
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
      ;; Emacs allocates 50x30 terminal cells (16x32 actual pixels).
      ;; Chafa uses a 10x20 virtual cell, so match 800x960 physical pixels.
      (should (member "80x48" (nth 2 recorded)))
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
        (should (string-match-p "kitty-graphics-chafa-v2-" result))
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

(ert-deftest my-kitty-graphics-chafa-matches-measured-cell-geometry ()
  "Scale Chafa's virtual cells to the actual terminal pixel dimensions."
  (let ((kitty-graphics--cell-pixel-width 16)
        (kitty-graphics--cell-pixel-height 32))
    (should (equal (my/kitty-graphics--chafa-output-size 50 30)
                   "80x48"))
    (should (equal (my/kitty-graphics--chafa-output-size 54 50)
                   "86x80"))))

(ert-deftest my-kitty-graphics-chafa-uses-per-terminal-measurements ()
  "Read per-terminal sizes even if the global cell dimensions are nil."
  (let ((kitty-graphics--cell-pixel-width nil)
        (kitty-graphics--cell-pixel-height nil)
        (kitty-graphics--target-terminal nil))
    (cl-letf (((symbol-function 'terminal-parameter)
               (lambda (_terminal key)
                 (pcase key
                   ('kitty-graphics-cell-w 16)
                   ('kitty-graphics-cell-h 32)))))
      (should (equal (my/kitty-graphics--chafa-output-size 50 30)
                     "80x48")))))

(ert-deftest my-kitty-graphics-chafa-uses-upstream-cell-fallback ()
  "Match kitty-graphics' 8x16 fallback without terminal size data."
  (let ((kitty-graphics--cell-pixel-width nil)
        (kitty-graphics--cell-pixel-height nil)
        (kitty-graphics--target-terminal nil))
    (cl-letf (((symbol-function 'terminal-parameter)
               (lambda (&rest _) nil)))
      (should (equal (my/kitty-graphics--chafa-output-size 50 30)
                     "40x24")))))

(ert-deftest my-kitty-graphics-chafa-cache-changes-with-cell-size ()
  "Pixel size changes must not reuse prior Sixel output."
  (let ((kitty-graphics--active-backend 'sixel)
        (kitty-graphics--cell-pixel-width 16)
        (kitty-graphics--cell-pixel-height 32))
    (cl-letf (((symbol-function 'my/kitty-graphics-wezterm-p)
               (lambda () t))
              ((symbol-function 'executable-find)
               (lambda (program)
                 (when (equal program "chafa")
                   "/opt/homebrew/bin/chafa"))))
      (let ((a (my/kitty-graphics-sixel-cache-path-with-chafa
                (lambda (&rest _) "old.six") "diagram.png" 54 50)))
        (let ((kitty-graphics--cell-pixel-width 20)
              (kitty-graphics--cell-pixel-height 40))
          (should-not
           (equal a (my/kitty-graphics-sixel-cache-path-with-chafa
                     (lambda (&rest _) "old.six")
                     "diagram.png" 54 50))))))))

;;; my-kitty-graphics-test.el ends here
