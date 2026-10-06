;;; my-window-test.el --- Tests for my-window -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-window' のテスト。

;;; Code:

(require 'ert)
(require 'my-window)


(ert-deftest my/toggle-window-split-direction-preserves-window-order ()
  "分割方向を切り替えてもバッファ順と選択ウィンドウを維持すること。"
  (save-window-excursion
    (delete-other-windows)
    (let ((first-buffer (generate-new-buffer " *my-window-first*"))
          (second-buffer (generate-new-buffer " *my-window-second*")))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) first-buffer)
            (let ((second-window (split-window-right)))
              (set-window-buffer second-window second-buffer)
              (select-window second-window))

            ;; 左右分割から上下分割へ切り替える。
            (my/toggle-window-split-direction)
            (let* ((root (frame-root-window))
                   (first (window-child root))
                   (second (window-next-sibling first)))
              (should (window-combined-p first))
              (should-not (window-combined-p first t))
              (should (eq (window-buffer first) first-buffer))
              (should (eq (window-buffer second) second-buffer))
              (should (eq (selected-window) second)))

            ;; 上下分割から左右分割へ戻す。
            (my/toggle-window-split-direction)
            (let* ((root (frame-root-window))
                   (first (window-child root))
                   (second (window-next-sibling first)))
              (should-not (window-combined-p first))
              (should (window-combined-p first t))
              (should (eq (window-buffer first) first-buffer))
              (should (eq (window-buffer second) second-buffer))
              (should (eq (selected-window) second))))
        (kill-buffer first-buffer)
        (kill-buffer second-buffer)))))


(ert-deftest my/toggle-window-split-direction-requires-two-windows ()
  "2分割以外では配置を変更せずエラーにすること。"
  (save-window-excursion
    (delete-other-windows)
    (should-error (my/toggle-window-split-direction)
                  :type 'user-error)))


;;; my-window-test.el ends here
