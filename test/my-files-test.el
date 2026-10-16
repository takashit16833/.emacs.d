;;; my-files-test.el --- Tests for my-files -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'my-files)


(ert-deftest my/dirvish-preview-below-moves-preview-window-below ()
  "Dirvishのプレビューを下側40%へ配置する。"
  (let ((buffer (get-buffer-create "*dirvish-preview@test*"))
        (args '((side . right) (window-width . 0.6)))
        received)
    (unwind-protect
        (cl-letf (((symbol-function 'window-total-height)
                   (lambda (&rest _) 100)))
          (my/dirvish-preview-below
           (lambda (_buffer alist)
             (setq received alist))
           buffer args)
          (should (eq (alist-get 'side received) 'below))
          (should (= (alist-get 'window-height received) -40))
          ;; 呼び出し元の引数は変更しない。
          (should (eq (alist-get 'side args) 'right)))
      (kill-buffer buffer))))


(ert-deftest my/dirvish-preview-below-keeps-other-windows ()
  "プレビュー以外のDirvishウィンドウ配置は変更しない。"
  (let ((buffer (get-buffer-create " *dirvish-header@test*"))
        (args '((side . above) (window-height . -2)))
        received)
    (unwind-protect
        (progn
          (my/dirvish-preview-below
           (lambda (_buffer alist)
             (setq received alist))
           buffer args)
          (should (equal received args)))
      (kill-buffer buffer))))


;;; my-files-test.el ends here
