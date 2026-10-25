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
            ;; `previous-buffer` は先頭が空白のバッファを履歴に記録しない。
            ;; 復元動作を検証するため、通常のバッファ名を使用する。
            (buffer-a (generate-new-buffer "*my-vterm-a*"))
            (buffer-b (generate-new-buffer "*my-vterm-b*")))
       (unwind-protect
           (cl-letf (((symbol-function 'vterm)
                      (lambda (&optional _arg)
                        (switch-to-buffer (get-buffer-create vterm-buffer-name)))))
             (setf (alist-get 'my/vterm-fullscreen
                              (cdr (assq 'current-tab (tab-bar-tabs)))) nil)
             (delete-other-windows)
             (switch-to-buffer buffer-a)
             ,@body)
         (setf (alist-get 'my/vterm-fullscreen
                          (cdr (assq 'current-tab (tab-bar-tabs)))) nil)
         (dolist (buffer (list (get-buffer buffer-name) buffer-a buffer-b))
           (when (buffer-live-p buffer)
             (kill-buffer buffer)))))))


(ert-deftest my/vterm-toggle-restores-split ()
  "通常起動は全面表示し、再実行で元の分割と選択先を戻す。"
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
    (set-window-buffer (split-window-right) buffer-b)
    (let ((exit (windmove-display-right)))
      (unwind-protect
          (progn
            (my/vterm-toggle)
            (should (= (length (window-list)) 2))
            (should (eq (window-buffer (selected-window)) buffer-a))
            (should (equal (buffer-name (window-buffer (next-window)))
                           buffer-name)))
        (funcall exit)))
    (my/vterm-toggle)
    (should (= (length (window-list)) 2))
    (should (eq (window-buffer (selected-window)) buffer-b))))


(ert-deftest my/vterm-toggle-one-window ()
  "もともと分割がない場合は通常のバッファ切り替えに戻る。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (should (one-window-p t))
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (eq (window-buffer) buffer-a))))


(ert-deftest my/vterm-toggle-does-not-restore-stale-layout ()
  "全面表示後に分割を変更した場合、古い配置を復元しない。"
  (my/vterm-test--with-buffers
    (set-window-buffer (split-window-right) buffer-b)
    (my/vterm-toggle)
    (set-window-buffer (split-window-right) buffer-b)
    (my/vterm-toggle)
    (should (= (length (window-list)) 2))
    (should (eq (window-buffer (next-window)) buffer-b))))


;;; my-vterm-test.el ends here
