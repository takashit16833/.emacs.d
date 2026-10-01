;;; editor.el --- Editing configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; 編集、移動、検索、補完、ファイル操作に関する設定を置く。

;;; Code:

(require 'my-editing)

;; 対応括弧を補完する
(electric-pair-mode 1)

;; Command+Sで現在のバッファを保存する。
(keymap-global-set "s-s" #'save-buffer)

;; 現在行または選択した行のコメントを切り替える。
(keymap-global-set "s-/" #'comment-line)

;; カーソル移動
(keymap-global-set "s-<up>" #'beginning-of-buffer)
(keymap-global-set "s-<down>" #'end-of-buffer)

;; 範囲選択中だけRETをクリップボードへのコピーに使用する。
(use-package selected
  :ensure t
  :demand t
  :bind
  (:map selected-keymap
        ("s-c" . my/copy-region-to-clipboard)))

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

;; プログラム編集中に補完候補を表示する。
(use-package corfu
  :ensure t
  :hook (prog-mode . corfu-mode)
  :custom
  ;; 1文字目から補完する。
  (corfu-auto t)
  (corfu-auto-prefix 1)

  ;; 補完候補の説明を１秒後に表示する。
  (corfu-popupinfo-delay 1.0)
  
  :config
  ;; RETは通常の改行にしようする。TABで補完する。
  (keymap-unset corfu-map "RET")
  
  ;; 補完候補の説明を表示する。
  (corfu-popupinfo-mode 1))

;; 補完候補にアイコンを表示する。
(use-package nerd-icons-corfu
  :ensure t
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters
               #'nerd-icons-corfu-formatter))

;; 表示中の文字へジャンプする。
(use-package avy
  :ensure t
  :bind ("s-j" . avy-goto-char-timer)
  :custom
  (avy-keys '(?o ?t ?a ?n ?i ?s ?e ?h)))

;;; editor.el ends here
