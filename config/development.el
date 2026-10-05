;;; development.el --- Development configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; プログラミング、Git、言語固有の開発設定を置く。

;;; Code:


;; Tree-sitterの色分けを最大レベルにする。
(setq treesit-font-lock-level 4)


;; プロジェクトの.editorconfigを反映する。
(use-package editorconfig
  :ensure nil
  :hook (after-init . editorconfig-mode))


;; LuaでTree-sitterを使用する。
(use-package lua-ts-mode
  :ensure nil
  :mode ("\\.lua\\'" . lua-ts-mode))


;; HaskellでTree-sitterを使用する。
(use-package haskell-ts-mode
  :vc (:url "https://github.com/dschrempf/haskell-ts-mode")
  :mode ("\\.hs\\'" . haskell-ts-mode))


;; 括弧を階層ごとに色分けする。
(use-package rainbow-delimiters
  :ensure t
  :hook
  (prog-mode . rainbow-delimiters-mode))


;;; LSP -------------------------------------------------------------


;; Language Server Protocolを利用する。
(use-package lsp-mode
  :ensure t
  :commands lsp-deferred
  :hook
  ((lua-ts-mode . lsp-deferred)
   (haskell-ts-mode . lsp-deferred))

  :init
  (setq lsp-keymap-prefix "C-c l")

  :custom
  ;; LSPの補完候補はEmacs標準のcompletion-at-pointへ登録する。
  ;; 候補の表示はCorfuに任せるため、company-modeは使用しない。
  (lsp-completion-provider :none)

  ;; 診断にはEmacs標準のFlymakeを使用する。
  (lsp-diagnostics-provider :flymake)

  ;; 入力中にはLanguage Serverによる自動整形を行わない。
  ;; 編集中のインデントは各major modeに任せる。
  (lsp-enable-on-type-formatting nil)
  (lsp-enable-indentation nil)

  ;; 保存時のコード変更はApheleiaなどの専用フォーマッタに任せる。
  (lsp-before-save-edits nil)

  ;; Tree-sitterによる色分けを使用するため、
  ;; LSPによるSemantic Tokensは一旦使用しない。
  (lsp-semantic-tokens-enable nil)

  ;; コード上に参照数などを常時表示するCode Lensは一旦使用しない。
  (lsp-lens-enable nil)

  ;; 既存のMood Lineと表示が重複するため、
  ;; lsp-mode独自のモードライン表示は使用しない。
  (lsp-modeline-code-actions-enable nil)
  (lsp-modeline-diagnostics-enable nil)
  (lsp-modeline-workspace-status-enable nil)

  ;; バッファ上部にパンくずリストを表示しない。
  (lsp-headerline-breadcrumb-enable nil))


;; Haskell Language Serverを使用する。
(use-package lsp-haskell
  :ensure t
  :after lsp-mode
  :custom
  ;; HLSから明示的に整形した場合もFourmoluを使用する。
  (lsp-haskell-formatting-provider "fourmolu")

  ;; HLS内蔵版ではなくPATH上のFourmoluを使用する。
  ;; Apheleiaと同じ実行ファイルを使うことで整形結果の差を防ぐ。
  (lsp-haskell-plugin-fourmolu-config-external t))


;; LSPのシンボルや診断をConsultから検索できるようにする。
(use-package consult-lsp
  :ensure t
  :after (consult lsp-mode)
  :commands
  (consult-lsp-symbols
   consult-lsp-file-symbols
   consult-lsp-diagnostics
   consult-lsp-file-diagnostics))


;; LSPの補完候補に含まれるスニペットを展開する。
(use-package yasnippet
  :ensure t
  :hook
  (lsp-mode . yas-minor-mode))


;;; Formatting ------------------------------------------------------


;; 外部フォーマッタを非同期で実行する。
(use-package apheleia
  :ensure t
  :hook
  ;; 保存時の整形も手動実行と同じApheleiaの設定を使用する。
  ((lua-ts-mode . apheleia-mode)
   (haskell-ts-mode . apheleia-mode))

  :config
  ;; LuaはStyLuaで整形する。
  ;;
  ;; --respect-ignores:
  ;;   .styluaignoreの設定を尊重する。
  ;;
  ;; --stdin-filepath:
  ;;   stdin経由でも元ファイルの場所をStyLuaへ伝える。
  ;;   設定ファイルの探索基準にも使われる。
  ;;
  ;; --search-parent-directories:
  ;;   親ディレクトリへ遡ってstylua.toml / .stylua.tomlを探す。
  (setf (alist-get 'stylua apheleia-formatters)
        '("stylua"
          "--respect-ignores"
          "--stdin-filepath" filepath
          "--search-parent-directories"
          "-"))

  ;; HaskellはFourmoluで整形する。
  ;; 元ファイルの場所を渡し、Fourmoluの設定やCabal情報を正しく探索させる。
  (setf (alist-get 'fourmolu apheleia-formatters)
        '("fourmolu" "--stdin-input-file" filepath))

  ;; haskell-ts-modeでは必ずFourmoluを使用する。
  (setf (alist-get 'haskell-ts-mode apheleia-mode-alist)
        'fourmolu))


;; 手動整形も保存時と同じApheleiaのformatter選択を使用する。
(with-eval-after-load 'lsp-mode
  (keymap-set lsp-command-map "= =" #'apheleia-format-buffer))


;;; development.el ends here
