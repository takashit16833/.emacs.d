;;; completion.el --- Completion configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; ミニバッファと補完UIに関する設定を置く。

;;; Code:


;; ミニバッファの入力履歴をEmacs終了後も保存する。
(use-package savehist
  :ensure nil
  :init
  (savehist-mode))


;; ミニバッファの候補を縦に一覧表示する。
(use-package vertico
  :ensure t
  :custom
  (vertico-count 20)
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
  (("s-f" . consult-line)
   ("S-s-f" . consult-ripgrep)
   ("s-r" . consult-recent-file)
   ("s-y" . consult-yank-pop)))


;; 補完候補やカーソル位置の対象に対して、その場で操作する。
(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)
   ("C-h B" . embark-bindings))
  :init
  ;; プレフィックスキーのヘルプをEmbarkで表示する。
  (setq prefix-help-command #'embark-prefix-help-command))


;; Consultの検索結果をEmbarkからexportできるようにする。
(use-package embark-consult
  :ensure t
  :defer t)


;; 補完候補にNerd Fontのアイコンを表示する。
(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook
            #'nerd-icons-completion-marginalia-setup))


;; プログラム編集中に補完候補を表示する。
(use-package corfu
  :ensure t
  :hook (prog-mode . corfu-mode)
  :custom
  ;; 2文字入力後、少し待ってから自動補完する。
  (corfu-auto t)
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.15)

  ;; 補完候補の説明を１秒後に表示する。
  (corfu-popupinfo-delay 1.0)

  :config
  ;; TTY child frame に枠を表示する。
  (setf (alist-get 'undecorated corfu--frame-parameters) nil)

  ;; Corfu の背景を Emacs 本体の背景に合わせる。
  (set-face-attribute 'corfu-default nil
                      :background (face-background 'default nil t))

  ;; RETは通常の改行にする。TABで補完する。
  (keymap-unset corfu-map "RET")

  ;; 補完候補の説明を表示する。
  (corfu-popupinfo-mode 1))

;; ポップアップの位置をずらす
(advice-add 'corfu--make-frame
            :around
            #'my/corfu-offset-tty-popup)


;; 補完候補にアイコンを表示する。
(use-package nerd-icons-corfu
  :ensure t
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters
               #'nerd-icons-corfu-formatter))


;; CAPF周りを補助するためのパッケージ
(use-package cape
  :ensure t
  :after lsp-mode
  :config
  ;; 入力が変わったらLSP補完候補を取り直す。
  (advice-add #'lsp-completion-at-point
              :around
              #'cape-wrap-buster))


;;; completion.el ends here
