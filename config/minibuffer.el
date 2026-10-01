;;; minibuffer.el --- Minibuffer settings -*- lexical-binding: t; -*-

;; ミニバッファの入力履歴をEmacs終了後も保存する。
;; Verticoは履歴も候補の並び順に利用する。
(use-package savehist
  :ensure nil
  :init
  (savehist-mode))

;; ミニバッファの候補を縦に一覧表示する。
(use-package vertico
  :ensure t
  :init
  (vertico-mode))

;; ミニバッファを利用した検索・選択コマンドを追加する。
(use-package consult
  :ensure t
  :bind
  (("C-x b" . consult-buffer)
   ("s-f" . consult-line)))

(provide 'minibuffer)
;;; minibuffer.el ends here