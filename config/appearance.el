;;; appearance.el --- Appearance configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs の表示と見た目に関する設定を置く。

;;; Code:


(require 'my-ui)


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


;; TTY child frame の枠を角丸にする。
;; 枠色はウィンドウ境界線と同じ `vertical-border' face を使う。
(set-display-table-slot standard-display-table
                        'box-vertical
                        (make-glyph-code ?│ 'vertical-border))
(set-display-table-slot standard-display-table
                        'box-horizontal
                        (make-glyph-code ?─ 'vertical-border))
(set-display-table-slot standard-display-table
                        'box-down-right
                        (make-glyph-code ?╭ 'vertical-border))
(set-display-table-slot standard-display-table
                        'box-down-left
                        (make-glyph-code ?╮ 'vertical-border))
(set-display-table-slot standard-display-table
                        'box-up-right
                        (make-glyph-code ?╰ 'vertical-border))
(set-display-table-slot standard-display-table
                        'box-up-left
                        (make-glyph-code ?╯ 'vertical-border))


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


;; 軽量なモードラインを使用する。
(use-package mood-line
  :ensure t
  :custom
  ;; Fira Code向けの記号セットを使用する。
  (mood-line-glyph-alist mood-line-glyphs-fira-code)
  :config
  ;; モードラインの左右に表示する情報と、その間隔を定義する。
  (setq mood-line-format
        (mood-line-defformat
         ;; モードライン全体の左右余白を追加しない。
         :padding ""
         ;; 左側に表示する情報。
         :left
         (;; モーダル編集状態。
          ((mood-line-segment-modal)                  . " ")
          ;; バッファの変更・読み取り専用などの状態。
          ((or (mood-line-segment-buffer-status) " ") . " ")
          ;; 開いているファイルのアイコン。
          ((my/mood-line-segment-file-icon)           . " ")
          ;; バッファ名。
          ((mood-line-segment-buffer-name)            . "  ")
          ;; 検索結果の現在位置と件数。
          ((mood-line-segment-anzu)                   . "  ")
          ;; multiple-cursorsの状態。
          ((mood-line-segment-multiple-cursors)       . "  ")
          ;; カーソルの行・列位置。
          ((mood-line-segment-cursor-position)        . " ")
          ;; バッファ内のスクロール位置。
          (mood-line-segment-scroll))
         ;; 右側に表示する情報。
         :right
         (;; Gitなどのバージョン管理情報。
          ((mood-line-segment-vc)         . "  ")
          ;; 現在のmajor mode。
          ((mood-line-segment-major-mode) . "  ")
          ;; Emacsや各modeが追加する補助情報。
          ((mood-line-segment-misc-info)  . "  ")
          ;; Flymakeなどの診断状態。
          ((mood-line-segment-checker)    . "  ")
          ;; 実行中の外部プロセス情報。
          ((mood-line-segment-process)    . "  "))))
  (mood-line-mode))


;;; appearance.el ends here
