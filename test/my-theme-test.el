;;; my-theme-test.el --- Tests for shared theme selection -*- lexical-binding: t; -*-

;;; Commentary:
;; テーマ名の読み書きと、切り替えの失敗時に元のテーマへ戻す処理を確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-theme)

(ert-deftest my/theme--selected-defaults-when-file-is-missing ()
  (let ((my/theme--state-file
         (make-temp-name (expand-file-name "retro-theme-" temporary-file-directory))))
    (should (eq (my/theme--selected) 'retro-hacker-blue))))

(ert-deftest my/theme--read-accepts-supported-theme ()
  (let ((my/theme--state-file (make-temp-file "retro-theme-")))
    (unwind-protect
        (progn
          (with-temp-file my/theme--state-file
            (insert "one-dark-blue\n"))
          (should (eq (my/theme--read) 'one-dark-blue)))
      (delete-file my/theme--state-file))))

(ert-deftest my/theme--read-accepts-previous-theme-name ()
  (let ((my/theme--state-file (make-temp-file "retro-theme-")))
    (unwind-protect
        (progn
          (with-temp-file my/theme--state-file
            (insert "retro-one-dark\n"))
          (should (eq (my/theme--read) 'one-dark-blue))
          (should (eq (my/theme--selected) 'one-dark-blue)))
      (delete-file my/theme--state-file))))

(ert-deftest my/theme--selected-ignores-unknown-theme ()
  (let ((my/theme--state-file (make-temp-file "retro-theme-")))
    (unwind-protect
        (progn
          (with-temp-file my/theme--state-file
            (insert "unknown-theme\n"))
          (should (eq (my/theme--selected) 'retro-hacker-blue)))
      (delete-file my/theme--state-file))))

(ert-deftest my/theme--save-persists-selection ()
  (let* ((directory (make-temp-file "retro-theme-" t))
         (my/theme--state-file (expand-file-name "state/retro-theme" directory)))
    (unwind-protect
        (progn
          (my/theme--save 'one-dark-blue)
          (should (eq (my/theme--read) 'one-dark-blue)))
      (delete-directory directory t))))

(ert-deftest my/theme--activate-rejects-unknown-theme ()
  (should-error (my/theme--activate 'unknown-theme) :type 'user-error))

(ert-deftest my/theme--activate-restores-previous-theme-on-error ()
  (let ((custom-enabled-themes '(original-theme))
        (disabled nil)
        (enabled nil))
    (cl-letf (((symbol-function 'disable-theme)
               (lambda (theme) (push theme disabled)))
              ((symbol-function 'load-theme)
               (lambda (&rest _) (error "Test load failure")))
              ((symbol-function 'enable-theme)
               (lambda (theme) (push theme enabled))))
      (should-error (my/theme--activate 'one-dark-blue) :type 'error)
      (should (equal disabled '(original-theme original-theme)))
      (should (equal enabled '(original-theme))))))

;;; my-theme-test.el ends here
