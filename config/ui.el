;;; ui.el --- User interface configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Emacs の表示と見た目に関する設定を置く。

;;; Code:

;; すべてのバッファで行を折り返す。
(setq-default truncate-lines nil)
(setq truncate-partial-width-windows nil)

;; 折り返し位置の「\」を空白に置き換える。
(require 'disp-table)
(set-display-table-slot standard-display-table 'wrap ?\s)

;; ウィンドウの境界線を細い縦棒にする。
(set-display-table-slot standard-display-table 'vertical-border ?│)


;;; ui.el ends here
