;;; minibuffer.el --- Minibuffer settings -*- lexical-binding: t; -*-

;; ミニバッファの入力履歴をEmacs終了後も保存する。
(use-package savehist
  :ensure nil
  :init
  (savehist-mode))


;; ミニバッファの候補を縦に一覧表示する。
(use-package vertico
  :ensure t
  :init
  (vertico-mode))


;; 空白で区切った複数の条件を、順序に関係なく候補へ一致させる。
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file (styles partial-completion))))
  (completion-pcm-leading-wildcard t))


;; 候補の右側に補足情報を表示する。
(use-package marginalia
  :ensure t
  :init
  (marginalia-mode))


;; ミニバッファを利用した検索・選択コマンドを追加する。
;; キーを実行するまでConsult本体は読み込まない。
(use-package consult
  :ensure t
  :bind
  (("C-x b" . consult-buffer)
   ("s-f" . consult-line)))


;; 補完候補にNerd Fontのアイコンを表示する。
(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook
            #'nerd-icons-completion-marginalia-setup))


;;; minibuffer.el ends here
