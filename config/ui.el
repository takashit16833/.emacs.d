;;; ui.el --- User interface configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Emacs の表示と見た目に関する設定を置く。

;;; Code:

;; 画面: 上部のメニューバーを隠す（下部のモードラインは残す）。
(menu-bar-mode -1)

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
    ;; モードラインではファイル種別ごとの色を使わず、文字色を継承する。
    (let ((nerd-icons-color-icons nil))
      (nerd-icons-icon-for-file buffer-file-name))))


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


(defun my/tab-bar-tab-name-padding (name _tab _i)
  "タブ名 NAME の左右に余白を加える。"
  (concat "  " name "  "))


(use-package tab-bar
  :ensure nil
  :demand t
  :config
  ;; 表示方法は tab-bar 読み込み後に設定する。
  (setq tab-bar-show t
        tab-bar-auto-width nil
        tab-bar-format '(tab-bar-format-tabs)
        tab-bar-separator " "
        tab-bar-tab-hints nil
        tab-bar-close-button-show nil
        tab-bar-new-button-show nil
        tab-bar-tab-name-format-functions
        '(my/tab-bar-tab-name-padding
          tab-bar-tab-name-format-face
          tab-bar-tab-name-format-mouse-face))
  (tab-bar-mode 1))


(defun my/tab-line-tab-name (buffer &optional _buffers)
  "BUFFER のタブ名を、ファイルアイコン付きで返す。"
  (with-current-buffer buffer
    (if buffer-file-name
        (let ((nerd-icons-color-icons nil))
          (concat
           (nerd-icons-icon-for-file buffer-file-name)
           " "
           (buffer-name buffer)))
      (buffer-name buffer))))


(defun my/tab-line-tab-name-format (tab tabs)
  "TAB の左右に余白を加えて表示する。"
  (let* ((formatted (tab-line-tab-name-format-default tab tabs))
         (properties (and (> (length formatted) 0)
                          (text-properties-at 0 formatted)))
         (left-padding (copy-sequence "  "))
         (right-padding (copy-sequence "  ")))
    (when properties
      (add-text-properties 0 (length left-padding)
                           properties left-padding)
      (add-text-properties 0 (length right-padding)
                           properties right-padding))
    (concat left-padding formatted right-padding)))


(use-package tab-line
  :ensure nil
  :demand t
  :config
  ;; tab-line-separator は defcustom ではないため、読み込み後に直接設定する。
  (setq tab-line-separator " "
        tab-line-new-button-show nil
        tab-line-close-button-show nil
        tab-line-tab-name-function #'my/tab-line-tab-name
        tab-line-tab-name-format-function #'my/tab-line-tab-name-format)
  (global-tab-line-mode 1))

;;; ui.el ends here
