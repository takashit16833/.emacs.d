;;; editing.el --- Editing configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; テキスト編集に関する設定を置く。

;;; Code:


(require 'my-editing)


;; 対応括弧を補完する
(electric-pair-mode 1)


;; C-w / M-wがOSのクリップボードを更新しないようにする。
(setq interprogram-cut-function nil)


;; OSのクリップボード貼り付け時にキルリングを更新しないようにする。
(setq xterm-store-paste-on-kill-ring nil)


;; Command+Sで現在のバッファを保存する。
(keymap-global-set "s-s" #'save-buffer)


;; 現在行または選択した行のコメントを切り替える。
(keymap-global-set "s-/" #'comment-line)


;; 現在行を削除する
(keymap-global-set "S-s-k" #'my/delete-whole-line)


;; Command+Aでバッファ全体を選択する。
(keymap-global-set "s-a" #'mark-whole-buffer)


;; カーソルを行頭・行末へ移動する。
(keymap-global-set "s-<left>" #'my/smart-beginning-of-line)
(keymap-global-set "s-<right>" #'end-of-line)


;; カーソル位置から行頭・行末までを選択する
(keymap-global-set "S-s-<left>" #'my/select-to-line-beginning)
(keymap-global-set "S-s-<right>" #'my/select-to-line-end)


;; 単語単位で削除する。
(keymap-global-set "M-<delete>" #'my/delete-word-forward)
(keymap-global-set "M-<backspace>" #'my/delete-word-backward)


;; カーソル行の下に新しい行を挿入し、その行へ移動する。
(keymap-global-set "s-<return>" #'my/insert-line-below)


;; カーソル行の上に新しい行を挿入し、その行へ移動する。
(keymap-global-set "S-s-<return>" #'my/insert-line-above)


;; カーソル移動
(keymap-global-set "s-<up>" #'beginning-of-buffer)
(keymap-global-set "s-<down>" #'end-of-buffer)


;; 現在行選択
(global-set-key (kbd "s-l") #'my/select-current-line)


;; 現在位置から行頭・行末まで削除する。
(global-set-key (kbd "s-<delete>") #'my/delete-to-line-end)
(global-set-key (kbd "s-<backspace>") #'my/delete-to-line-beginning)


;; 選択範囲またはカーソル行のテキストを複製する。
(global-set-key (kbd "S-M-<up>") #'my/duplicate-lines-up)
(global-set-key (kbd "S-M-<down>") #'my/duplicate-lines-down)


;; クリップボードへコピーする。
(use-package selected
  :ensure t
  :demand t
  :bind
  (:map selected-keymap
        ("w"   . kill-ring-save)
        ("s-c" . my/copy-region-to-clipboard))
  :config
  (selected-global-mode 1))


;; Clutchの結果コピーだけOSのクリップボードにも反映する。
(add-hook 'clutch-result-mode-hook
          (lambda ()
            (setq-local interprogram-cut-function
                        (lambda (text)
                          (gui-set-selection 'CLIPBOARD text)))))


;; 行スワップ
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
         ("S-s-z" . undo-fu-only-redo)))


;;; editing.el ends here
