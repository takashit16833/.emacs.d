;;; my-vterm-test.el --- Tests for my-vterm -*- lexical-binding: t; -*-

;;; Commentary:
;; vtermの実プロセスを起動せず、表示先と分割の復元を検証する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-vterm)


(defmacro my/vterm-test--with-buffers (&rest body)
  "テスト用のバッファとvterm起動の代役を使ってBODYを実行する。"
  (declare (indent 0))
  `(save-window-excursion
     (let* ((project-current-directory-override
             (make-temp-name (expand-file-name "vterm-test-" temporary-file-directory)))
            (buffer-name (my/vterm--buffer-name project-current-directory-override))
            (buffer-a (generate-new-buffer "*my-vterm-a*"))
            (buffer-b (generate-new-buffer "*my-vterm-b*"))
            (created nil))
       (unwind-protect
           (cl-letf (((symbol-function 'vterm)
                      (lambda (&optional arg)
                        (let ((buffer (if arg
                                          (generate-new-buffer vterm-buffer-name)
                                        (get-buffer-create vterm-buffer-name))))
                          (push buffer created)
                          (with-current-buffer buffer
                            (setq major-mode 'vterm-mode))
                          (switch-to-buffer buffer)
                          buffer))))
             (my/fullscreen-clear 'my/vterm-fullscreen)
             (my/fullscreen-clear 'my/vterm-layout)
             (delete-other-windows)
             (switch-to-buffer buffer-a)
             ,@body)
         (my/fullscreen-clear 'my/vterm-fullscreen)
         (my/fullscreen-clear 'my/vterm-layout)
         (dolist (buffer (append created (list buffer-a buffer-b)))
           (when (buffer-live-p buffer)
             (kill-buffer buffer)))))))


(ert-deftest my/vterm-toggle-restores-split ()
  "通常起動は全面表示し、再実行で元の編集画面を戻す。"
  (my/vterm-test--with-buffers
    (set-window-buffer (split-window-right) buffer-b)
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (equal (buffer-name (window-buffer)) buffer-name))
    (my/vterm-toggle)
    (should (= (length (window-list)) 2))
    (should (eq (window-buffer (selected-window)) buffer-a))
    (should (eq (window-buffer (next-window)) buffer-b))))


(ert-deftest my/vterm-toggle-windmove-keeps-split ()
  "windmoveで右を指定したときは分割状態を維持する。"
  (my/vterm-test--with-buffers
    (let* ((left (selected-window))
           (right (split-window-right)))
      (set-window-buffer right buffer-b)
      (let ((exit (windmove-display-right)))
        (unwind-protect
            (progn
              (my/vterm-toggle)
              (should (= (length (window-list)) 2))
              (should (eq (selected-window) right))
              (should (eq (window-buffer left) buffer-a))
              (should (eq (window-buffer right) (get-buffer buffer-name))))
          (funcall exit)))
      (my/vterm-toggle)
      (should (= (length (window-list)) 2))
      (should (eq (selected-window) right))
      (should (eq (window-buffer left) buffer-a))
      (should (eq (window-buffer right) buffer-b)))))


(ert-deftest my/vterm-toggle-one-window ()
  "単一ウィンドウからでも編集画面へ戻り、再度vtermを開ける。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (my/fullscreen-get 'my/vterm-fullscreen))
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (eq (window-buffer) buffer-a))
    (my/vterm-toggle)
    (should (equal (buffer-name (window-buffer)) buffer-name))))


(ert-deftest my/vterm-split-and-toggle-restores-both-layouts ()
  "vtermを分割した後、s-j相当の切り替えで両方の配置が復元される。"
  (my/vterm-test--with-buffers
    (set-window-buffer (split-window-right) buffer-b)
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below))))
        (my/vterm-split))
      (let ((second (current-buffer)))
        (should-not (eq first second))
        (should (= (length (window-list)) 2))
        (should (get-buffer-window first))
        (my/vterm-toggle)
        (should (= (length (window-list)) 2))
        (should (eq (current-buffer) buffer-a))
        (should (get-buffer-window buffer-b))
        (my/vterm-toggle)
        (should (= (length (window-list)) 2))
        (should (eq (current-buffer) second))
        (should (get-buffer-window first))
        (should (get-buffer-window second))))))


(ert-deftest my/vterm-split-only-in-vterm ()
  "vterm以外では分割コマンドが実行できない。"
  (my/vterm-test--with-buffers
    (should-error (my/vterm-split) :type 'user-error)
    (should (one-window-p t))))


(ert-deftest my/vterm-split-fails-without-space ()
  "分割できない場合は既存の画面を変更しない。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional _window) nil)))
        (should-error (my/vterm-split) :type 'user-error))
      (should (one-window-p t))
      (should (eq (current-buffer) first)))))


(ert-deftest my/vterm-split-rolls-back-on-startup-error ()
  "新しいvtermの起動失敗時は分割したウィンドウを閉じる。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below)))
                ((symbol-function 'vterm)
                 (lambda (&optional _arg)
                   (error "Test startup error"))))
        (should-error (my/vterm-split) :type 'error))
      (should (one-window-p t))
      (should (eq (current-buffer) first)))))


;;; my-vterm-test.el ends here
