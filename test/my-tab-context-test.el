;;; my-tab-context-test.el --- Tab-context Dirvish tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Dirvishの再利用時にも編集ファイルへの追従が行われることを確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-tab-context)

;; パッケージを読み込まずに関数を差し替えてテストできるようにする。
(autoload 'dirvish "dirvish")
(autoload 'dirvish-subtree-expand-to "dirvish-subtree")
(autoload 'dirvish--redisplay "dirvish")


(ert-deftest my/project-dirvish-follows-each-file-on-session-reuse ()
  "同じDirvishバッファを再利用しても毎回現在のファイルを選択する。"
  (let* ((root (make-temp-file "my-dirvish-follow-" t))
         (first-file (expand-file-name "first.el" root))
         (second-file (expand-file-name "second.el" root))
         (dirvish-buf (generate-new-buffer " *my-dirvish-reuse-test*"))
         (targets nil)
         (redraws 0))
    (unwind-protect
        (save-window-excursion
          (dolist (file (list first-file second-file))
            (with-temp-file file (insert "test")))
          (with-current-buffer dirvish-buf
            (setq-local major-mode 'dired-mode)
            (setq-local default-directory root))
          (let ((features (cons 'dirvish-subtree features)))
            (cl-letf (((symbol-function 'my/tab-context-directory)
                       (lambda () root))
                      ((symbol-function 'dirvish)
                       (lambda (_root) (switch-to-buffer dirvish-buf)))
                      ((symbol-function 'dirvish-subtree-expand-to)
                       (lambda (target)
                         (push target targets)
                         target))
                      ((symbol-function 'dirvish--redisplay)
                       (lambda () (cl-incf redraws))))
              (dolist (file (list first-file second-file))
                (with-temp-buffer
                  (setq-local buffer-file-name file)
                  (switch-to-buffer (current-buffer))
                  (my/project-dirvish)))
              (should (equal (nreverse targets)
                             (list first-file second-file)))
              (should (= redraws 2)))))
      (when (buffer-live-p dirvish-buf)
        (kill-buffer dirvish-buf))
      (delete-directory root t))))


;;; my-tab-context-test.el ends here
