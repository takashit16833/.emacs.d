;;; my-window-test.el --- Tests for my-window -*- lexical-binding: t; -*-

;;; Commentary:
;; my-window のテスト。

;;; Code:

(require 'ert)
(require 'my-window)


(defun my/window-test--layout-signature (&optional window)
  "WINDOW 以下の分割方向とbuffer配置を簡潔なリストで返す。"
  (setq window (or window (frame-root-window)))
  (if (window-live-p window)
      (buffer-name (window-buffer window))
    (cons
     (if (window-left-child window) 'horizontal 'vertical)
     (mapcar #'my/window-test--layout-signature
             (my/window--children window)))))


(defun my/window-test--buffers ()
  "レイアウトテスト用のbufferを3個作成して返す。"
  (list (generate-new-buffer " *my-window-1*")
        (generate-new-buffer " *my-window-2*")
        (generate-new-buffer " *my-window-3*")))


(defun my/window-test--kill-buffers (buffers)
  "BUFFERS をすべて破棄する。"
  (dolist (buffer buffers)
    (when (buffer-live-p buffer)
      (kill-buffer buffer))))


(ert-deftest my/toggle-window-split-direction-three-siblings ()
  "123 を縦の1/2/3へ反転し、もう一度反転すると元へ戻ること。"
  (save-window-excursion
    (delete-other-windows)
    (let* ((buffers (my/window-test--buffers))
           (buffer-1 (nth 0 buffers))
           (buffer-2 (nth 1 buffers))
           (buffer-3 (nth 2 buffers)))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) buffer-1)
            (let ((window-2 (split-window-right)))
              (set-window-buffer window-2 buffer-2)
              (let ((window-3 (split-window-right nil window-2)))
                (set-window-buffer window-3 buffer-3))
              (select-window window-2))

            (should
             (equal (my/window-test--layout-signature)
                    '(horizontal
                      " *my-window-1*"
                      " *my-window-2*"
                      " *my-window-3*")))

            (my/toggle-window-split-direction)

            (should
             (equal (my/window-test--layout-signature)
                    '(vertical
                      " *my-window-1*"
                      " *my-window-2*"
                      " *my-window-3*")))
            (should (eq (window-buffer (selected-window)) buffer-2))

            (my/toggle-window-split-direction)

            (should
             (equal (my/window-test--layout-signature)
                    '(horizontal
                      " *my-window-1*"
                      " *my-window-2*"
                      " *my-window-3*")))
            (should (eq (window-buffer (selected-window)) buffer-2)))
        (my/window-test--kill-buffers buffers)))))


(ert-deftest my/toggle-window-split-direction-right-nested ()
  "12/13 を 11/23 の配置へ反転すること。"
  (save-window-excursion
    (delete-other-windows)
    (let* ((buffers (my/window-test--buffers))
           (buffer-1 (nth 0 buffers))
           (buffer-2 (nth 1 buffers))
           (buffer-3 (nth 2 buffers)))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) buffer-1)
            (let ((window-2 (split-window-right)))
              (set-window-buffer window-2 buffer-2)
              (let ((window-3 (split-window-below nil window-2)))
                (set-window-buffer window-3 buffer-3)))

            (should
             (equal (my/window-test--layout-signature)
                    '(horizontal
                      " *my-window-1*"
                      (vertical
                       " *my-window-2*"
                       " *my-window-3*"))))

            (my/toggle-window-split-direction)

            (should
             (equal (my/window-test--layout-signature)
                    '(vertical
                      " *my-window-1*"
                      (horizontal
                       " *my-window-2*"
                       " *my-window-3*")))))
        (my/window-test--kill-buffers buffers)))))


(ert-deftest my/toggle-window-split-direction-left-nested ()
  "12/32 を 13/22 の配置へ反転すること。"
  (save-window-excursion
    (delete-other-windows)
    (let* ((buffers (my/window-test--buffers))
           (buffer-1 (nth 0 buffers))
           (buffer-2 (nth 1 buffers))
           (buffer-3 (nth 2 buffers)))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) buffer-1)
            (let ((window-2 (split-window-right)))
              (set-window-buffer window-2 buffer-2))
            (let ((window-3 (split-window-below)))
              (set-window-buffer window-3 buffer-3))

            (should
             (equal (my/window-test--layout-signature)
                    '(horizontal
                      (vertical
                       " *my-window-1*"
                       " *my-window-3*")
                      " *my-window-2*")))

            (my/toggle-window-split-direction)

            (should
             (equal (my/window-test--layout-signature)
                    '(vertical
                      (horizontal
                       " *my-window-1*"
                       " *my-window-3*")
                      " *my-window-2*"))))
        (my/window-test--kill-buffers buffers)))))


(ert-deftest my/toggle-window-split-direction-requires-split-window ()
  "1ウィンドウだけのときは配置を変更せずエラーにすること。"
  (save-window-excursion
    (delete-other-windows)
    (should-error (my/toggle-window-split-direction)
                  :type 'user-error)))


;;; my-window-test.el ends here
