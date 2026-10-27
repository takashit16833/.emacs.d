;;; my-centered-text-test.el --- Centered layout tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'my-centered-text)

(ert-deftest my/centered-text-width ()
  "115列より広いときだけ、中央の本文幅を制限する。"
  (should (equal (my/centered-text--center-margins 90) '(0 . 0)))
  (should (equal (my/centered-text--center-margins 115) '(0 . 0)))
  (should (equal (my/centered-text--center-margins 116) '(0 . 1)))
  (should (equal (my/centered-text--center-margins 175) '(30 . 30)))
  (should (equal (my/centered-text--center-margins 180) '(32 . 33))))

(ert-deftest my/centered-text-follows-resize-and-buffer-switch ()
  "再計算時に余白は累積せず、別バッファ表示時は元へ戻る。"
  (with-temp-buffer
    (setq-local my/centered-text-mode t)
    (let* ((window (selected-window))
           (view (current-buffer))
           (other (generate-new-buffer " *markdown-layout-other*"))
           (displayed view)
           (total-width 175)
           (margins '(2 . 1))
           (minimum '(4 . 4))
           (layout nil))
      (unwind-protect
          (cl-letf (((symbol-function 'window-buffer)
                     (lambda (_) displayed))
                    ((symbol-function 'window-body-width)
                     (lambda (&rest _)
                       (- total-width
                          (car (my/centered-text--normalized-margins margins))
                          (cdr (my/centered-text--normalized-margins margins)))))
                    ((symbol-function 'window-margins)
                     (lambda (&rest _) margins))
                    ((symbol-function 'set-window-margins)
                     (lambda (_ left right)
                       (setq margins (cons left right))))
                    ((symbol-function 'window-parameter)
                     (lambda (_ key)
                       (pcase key
                         ('my/centered-text--layout layout)
                         ('min-margins minimum))))
                    ((symbol-function 'set-window-parameter)
                     (lambda (_ key value)
                       (pcase key
                         ('my/centered-text--layout (setq layout value))
                         ('min-margins (setq minimum value))))))
            (my/centered-text--update-window window)
            (should (equal margins '(30 . 30)))
            (should (equal minimum '(0 . 0)))
            (my/centered-text--update-window window)
            (should (equal margins '(30 . 30)))
            (setq total-width 130)
            (my/centered-text--update-window window)
            (should (equal margins '(7 . 8)))
            (setq displayed other)
            (my/centered-text--update-window window)
            (should (equal margins '(2 . 1)))
            (should (equal minimum '(4 . 4)))
            (should-not layout))
        (kill-buffer other)))))

(ert-deftest my/centered-text-mode-toggle ()
  "Org and Markdown can independently enable or disable centering."
  (with-temp-buffer
    (cl-letf (((symbol-function 'my/centered-text--watch-windows) #'ignore)
              ((symbol-function 'my/centered-text--refresh-windows) #'ignore))
      (my/centered-text-mode 1)
      (should my/centered-text-mode)
      (my/centered-text-mode -1)
      (should-not my/centered-text-mode))))

(provide 'my-centered-text-test)
;;; my-centered-text-test.el ends here
