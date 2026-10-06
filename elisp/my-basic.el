;;; my-basic.el --- Basic Emacs utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs全体の基本動作に関する独自機能を定義する。
;;
;; 設定値やキーバインドなどは `config/basic.el' に置き、
;; ここには独自関数などの実装を置く。

;;; Code:


(defun my/reload-init-file ()
  "init.elを再読み込みする。"
  (interactive)
  (condition-case err
      (progn
	(load-file (expand-file-name "init.el" user-emacs-directory))
	(message "init.el を再読み込みしました"))
    (error
     (message "init.el を再読み込みに失敗しました: %s" err))))


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


(provide 'my-basic)

;;; my-basic.el ends here
