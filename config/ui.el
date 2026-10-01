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

;; ファイル種別に応じたアイコンを取得する。
(use-package nerd-icons
  :ensure t
  :commands nerd-icons-icon-for-file)

;; 最強のカラーテーマ
(use-package retro-hacker-blue-theme
  :vc (:url "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git"
       :rev :newest)
  :no-require t
  :init
  (setq retro-hacker-blue-transparent-background t)
  :config
  (load-theme 'retro-hacker-blue t)
  (retro-hacker-blue-apply-background))

(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (when buffer-file-name
    (nerd-icons-icon-for-file buffer-file-name)))

;; ファイル種別に応じたアイコンを取得する。
(use-package nerd-icons
  :ensure t
  :commands nerd-icons-icon-for-file)

(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (when buffer-file-name
    (nerd-icons-icon-for-file buffer-file-name)))

;; 軽量なモードラインを使用する。
(use-package mood-line
  :ensure t
  :custom
  (mood-line-glyph-alist mood-line-glyphs-fira-code)
  :config
  (setq mood-line-format
        (mood-line-defformat
	 :padding ""
         :left
         (((mood-line-segment-modal)                  . " ")
          ((or (mood-line-segment-buffer-status) " ") . " ")
          ((my/mood-line-segment-file-icon)           . " ")
          ((mood-line-segment-buffer-name)            . "  ")
          ((mood-line-segment-anzu)                   . "  ")
          ((mood-line-segment-multiple-cursors)       . "  ")
          ((mood-line-segment-cursor-position)        . " ")
          (mood-line-segment-scroll))
         :right
         (((mood-line-segment-vc)         . "  ")
          ((mood-line-segment-major-mode) . "  ")
          ((mood-line-segment-misc-info)  . "  ")
          ((mood-line-segment-checker)    . "  ")
          ((mood-line-segment-process)    . "  "))))

  (mood-line-mode))

;;; ui.el ends here
