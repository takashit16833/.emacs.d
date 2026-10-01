;;; editor.el --- Editing configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 編集、移動、検索、補完、ファイル操作に関する設定を置く。

;;; Code:
 
;; ターミナル版Emacsでマウス操作を有効にする。
(unless (display-graphic-p)
  (xterm-mouse-mode 1))

;; スクロール: 上下端の5行手前から追従し、1行移動で画面が大きく跳ねないようにする。
(setq scroll-margin 5
      scroll-conservatively 101)

;; 対応括弧を補完する
(electric-pair-mode 1)

;; Command+Sで現在のバッファを保存する。
(keymap-global-set "s-s" #'save-buffer)

;; 現在行または選択した行のコメントを切り替える。
(keymap-global-set "s-/" #'comment-line)

;;; editor.el ends here
