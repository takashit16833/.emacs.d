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
  (lua-ts-mode . lsp-deferred)
  
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
  ;; Luaファイルを保存するとStyLuaで整形する。
  (lua-ts-mode . apheleia-mode)

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
          "-")))


;;; development.el ends here
