;;; my-basic.el --- Basic Emacs utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs全体の基本動作に関する独自機能を定義する。
;;
;; 設定値やキーバインドなどは `config/core.el' に置き、
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


(provide 'my-basic)

;;; my-basic.el ends here
