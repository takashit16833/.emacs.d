;;; editor.el --- Editing configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 編集、移動、検索、補完、ファイル操作に関する設定を置く。

;;; Code:

;; 対応括弧を補完する
(electric-pair-mode 1)

;; Command+Sで現在のバッファを保存する。
(keymap-global-set "s-s" #'save-buffer)

;; 現在行または選択した行のコメントを切り替える。
(keymap-global-set "s-/" #'comment-line)

;; VSCodeの行スワップ
(use-package move-text
  :ensure t
  :bind
  (("M-<up>"   . move-text-up)
   ("M-<down>" . move-text-down)))

;; 選択範囲を単語や括弧などの単位で広げる。
(use-package expand-region
  :ensure t
  :bind ("s-x" . er/expand-region))

;; Undo / Redo: Command（Super）とOption（Meta）のZを割り当てる。
(use-package undo-fu
  :ensure t
  :bind (("s-z" . undo-fu-only-undo)
         ("s-Z" . undo-fu-only-redo)
         ;; 暫定対応: WezTermから届くShift付きのSuperキーを受け付ける。
         ("S-s-z" . undo-fu-only-redo)
         ("M-z" . undo-fu-only-undo)
         ("M-Z" . undo-fu-only-redo)))

;;; editor.el ends here
