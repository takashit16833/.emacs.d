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

(use-package retro-hacker-blue-theme
  :vc (:url "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git"
       :rev :newest)
  :no-require t
  :init
  (setq retro-hacker-blue-transparent-background t)
  :config
  (load-theme 'retro-hacker-blue t)
  (retro-hacker-blue-apply-background))

;;; ui.el ends here
