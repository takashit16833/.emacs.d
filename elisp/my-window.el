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


(provide 'my-window)

;;; my-window.el ends here
