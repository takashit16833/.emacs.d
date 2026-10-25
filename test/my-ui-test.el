;;; my-ui-test.el --- Display table helper tests -*- lexical-binding: t; -*-

;;; Commentary:
;; 行番号表示に応じた境界線の切り替えを確認する。

;;; Code:

(require 'ert)
(require 'disp-table)
(require 'my-ui)

(defmacro my/ui-test--with-buffers (&rest body)
  "Run BODY with three temporary buffers and a restored window layout."
  (declare (indent 0))
  `(let ((buffers (list (generate-new-buffer " *my-ui-a*")
                        (generate-new-buffer " *my-ui-b*")
                        (generate-new-buffer " *my-ui-c*"))))
     (unwind-protect
         (save-window-excursion
           (delete-other-windows)
           (set-window-buffer (selected-window) (nth 0 buffers))
           ,@body)
       (dolist (buffer buffers)
         (when (buffer-live-p buffer)
           (kill-buffer buffer))))))


(ert-deftest my/update-vertical-borders-uses-right-buffer ()
  "The right buffer's line numbers determine whether the border shows."
  (my/ui-test--with-buffers
    (let* ((left (selected-window))
           (right (split-window-right))
           (a (nth 0 buffers))
           (b (nth 1 buffers)))
      (set-window-buffer right b)
      (dolist (case '((nil nil ?│) (t nil ?│)
                      (nil t ?\s) (t t ?\s)))
        (with-current-buffer a
          (setq-local display-line-numbers-mode (nth 0 case)))
        (with-current-buffer b
          (setq-local display-line-numbers-mode (nth 1 case)))
        (my/update-vertical-borders)
        (should (eq (display-table-slot (window-display-table left)
                                        'vertical-border)
                    (nth 2 case)))))))


(ert-deftest my/update-vertical-borders-independent-per-window ()
  "Two windows showing the same buffer can have different borders."
  (my/ui-test--with-buffers
    (let* ((left (selected-window))
           (middle (split-window-right))
           (right (split-window middle nil 'right))
           (shared (nth 0 buffers))
           (plain (nth 1 buffers)))
      (set-window-buffer middle shared)
      (set-window-buffer right plain)
      (with-current-buffer shared (setq-local display-line-numbers-mode t))
      (with-current-buffer plain (setq-local display-line-numbers-mode nil))
      (my/update-vertical-borders)
      (should (eq (display-table-slot (window-display-table left)
                                      'vertical-border) ?\s))
      (should (eq (display-table-slot (window-display-table middle)
                                      'vertical-border) ?│))
      (should-not (eq (window-display-table left)
                      (window-display-table middle))))))


(ert-deftest my/update-vertical-borders-mixed-right-neighbors ()
  "Draw the border if any of multiple right neighbors lacks line numbers."
  (my/ui-test--with-buffers
    (let* ((left (selected-window))
           (top-right (split-window-right))
           (bottom-right (split-window top-right nil 'below))
           (b (nth 1 buffers))
           (c (nth 2 buffers)))
      (set-window-buffer top-right b)
      (set-window-buffer bottom-right c)
      (with-current-buffer b (setq-local display-line-numbers-mode t))
      (with-current-buffer c (setq-local display-line-numbers-mode nil))
      (my/update-vertical-borders)
      (should (eq (display-table-slot (window-display-table left)
                                      'vertical-border) ?│))
      (with-current-buffer c (setq-local display-line-numbers-mode t))
      (my/update-vertical-borders)
      (should (eq (display-table-slot (window-display-table left)
                                      'vertical-border) ?\s)))))


(ert-deftest my/update-vertical-borders-preserves-display-tables ()
  "Preserve buffer display tables across buffer switches and updates."
  (let ((standard-display-table (make-display-table)))
    (set-display-table-slot standard-display-table 'vertical-border ?│)
    (my/ui-test--with-buffers
      (let* ((left (selected-window))
             (right (split-window-right))
             (a (nth 0 buffers))
             (b (nth 1 buffers))
             (c (nth 2 buffers))
             (table-a (make-display-table))
             (table-c (make-display-table)))
        (set-display-table-slot table-a 'wrap ?~)
        (set-display-table-slot table-c 'wrap ?#)
        (with-current-buffer a (setq-local buffer-display-table table-a))
        (with-current-buffer c (setq-local buffer-display-table table-c))
        (with-current-buffer b (setq-local display-line-numbers-mode t))
        (set-window-buffer right b)
        (my/update-vertical-borders)
        (let ((original (window-display-table left)))
          (my/update-vertical-borders)
          (should (eq (window-display-table left) original)))
        (should (eq (display-table-slot (window-display-table left)
                                        'wrap) ?~))
        (should (eq (display-table-slot standard-display-table
                                        'vertical-border) ?│))
        (should-not (display-table-slot table-a 'vertical-border))
        (set-window-buffer left c)
        (my/update-vertical-borders)
        (should (eq (display-table-slot (window-display-table left)
                                        'wrap) ?#))
        (should-not (display-table-slot table-c 'vertical-border))))))


(ert-deftest my/update-vertical-borders-for-buffer-refreshes-neighbor ()
  "A right buffer's mode change immediately updates the left border."
  (my/ui-test--with-buffers
    (let* ((left (selected-window))
           (right (split-window-right))
           (b (nth 1 buffers)))
      (set-window-buffer right b)
      (my/update-vertical-borders)
      (should (eq (display-table-slot (window-display-table left)
                                      'vertical-border) ?│))
      (with-current-buffer b
        (setq-local display-line-numbers-mode t)
        (my/update-vertical-borders-for-buffer))
      (should (eq (display-table-slot (window-display-table left)
                                      'vertical-border) ?\s)))))

(ert-deftest my/display-line-numbers-for-text-skips-org-and-markdown ()
  "OrgとMarkdownでは本文左端の行番号を表示しない。"
  (dolist (mode '(org-mode markdown-ts-mode))
    (with-temp-buffer
      ;; derived-mode-p は現在の major-mode 自体にも一致する。
      (setq-local major-mode mode)
      (my/display-line-numbers-for-text)
      (should-not display-line-numbers-mode))))

(ert-deftest my/display-line-numbers-for-text-enables-other-text ()
  "通常のテキストバッファでは引き続き行番号を表示する。"
  (with-temp-buffer
    (text-mode)
    (my/display-line-numbers-for-text)
    (should display-line-numbers-mode)))

;;; my-ui-test.el ends here
