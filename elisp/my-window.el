;;; my-window.el --- Window helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; ウィンドウの配置や表示状態を操作する独自コマンドを定義する。

;;; Code:


;; 現在のウィンドウを最大化・復元する。
(defun my/toggle-window-zoom ()
  "現在のタブでウィンドウの最大化を切り替える。"
  (interactive)
  (let* ((tab (assq 'current-tab (tab-bar-tabs)))
         (saved (alist-get 'my/window-zoom (cdr tab))))
    (if saved
        (progn
          (set-window-configuration saved)
          (setf (alist-get 'my/window-zoom (cdr tab)) nil))
      (unless (one-window-p t)
        (setf (alist-get 'my/window-zoom (cdr tab))
              (current-window-configuration))
        (maximize-window)))))


(defun my/toggle-window-split-direction ()
  "2分割されたウィンドウの方向を左右と上下で切り替える。"
  (interactive)
  (let ((windows (window-list nil 'no-minibuffer)))
    (unless (= (length windows) 2)
      (user-error "2分割のときだけ使用できます"))
    (let* ((root (frame-root-window))
           (first (window-child root))
           (second (and first (window-next-sibling first)))
           (selected (selected-window)))
      ;; Side Window などを含む特殊な配置は対象にしない。
      (unless (and (window-live-p first)
                   (window-live-p second)
                   (null (window-next-sibling second))
                   (memq selected (list first second)))
        (user-error "単純な2分割のときだけ使用できます"))
      (let ((first-state (window-state-get first))
            (second-state (window-state-get second))
            (side-by-side (window-combined-p first t))
            (selected-first (eq selected first)))
        (delete-other-windows first)
        (let ((new-window
               (if side-by-side
                   (split-window-below nil first)
                 (split-window-right nil first))))
          (window-state-put first-state first)
          (window-state-put second-state new-window)
          (select-window (if selected-first first new-window)))))))


(provide 'my-window)

;;; my-window.el ends here
