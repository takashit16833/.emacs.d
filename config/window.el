;;; window.el --- Window configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; ウィンドウの移動、分割、配置に関する設定を置く。

;;; Code:


(require 'my-window)


;; 次のウィンドウへ移動する。
(keymap-global-set "M-o" #'other-window)


;; 現在のウィンドウを最大化・復元する。
(keymap-global-set "M-z" #'my/toggle-window-zoom)


;; VS Code と同じ Command+Option+0 で分割方向を切り替える。
(keymap-global-set "M-s-0" #'my/toggle-window-split-direction)


;; 矢印方向へバッファの表示先を移動する。
(use-package windmove
  :ensure nil
  :bind
  (("C-c <left>"  . windmove-display-left)
   ("C-c <right>" . windmove-display-right)
   ("C-c <up>"    . windmove-display-up)
   ("C-c <down>"  . windmove-display-down)))


;;; window.el ends here
