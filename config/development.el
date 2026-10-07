;;; development.el --- Development configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; プログラミング、Git、言語固有の開発設定を置く。

;;; Code:


(require 'my-development)
(require 'my-lsp-problems)


;; Tree-sitterの色分けを最大レベル（４が最大）。
(setq treesit-font-lock-level 3)

;; PythonではEmacs標準のTree-sitter modeを使用する。
;; Emacs 31.1では `treesit-enabled-modes' が
;; `major-mode-remap-alist' への反映を管理する。
(setopt treesit-enabled-modes '(python-ts-mode))


;; プロジェクトの.editorconfigを反映する。
(use-package editorconfig
  :ensure nil
  :hook (after-init . editorconfig-mode))


;; 括弧を階層ごとに色分けする。
(use-package rainbow-delimiters
  :ensure t
  :hook
  (prog-mode . rainbow-delimiters-mode))


;; 診断マーカーはdiff-hlと重ならないよう右marginへ表示する。
(use-package flymake
  :ensure nil
  :custom
  (flymake-indicator-type 'margins)
  (flymake-margin-indicator-position 'right-margin)
  ;; VS Code と同じ Codicons を使う。
  (flymake-margin-indicators-string
   '((error "" compilation-error)
     (warning "" compilation-warning)
     (note "" compilation-info))))


;;; Lua -------------------------------------------------------------

;; LuaでTree-sitterを使用する。
(use-package lua-ts-mode
  :ensure nil
  :mode ("\\.lua\\'" . lua-ts-mode))


;;; Haskell ---------------------------------------------------------

;; Cabalファイルを色分けする。
(use-package haskell-mode
  :ensure t
  :mode
  ("\\.cabal\\'" . haskell-cabal-mode)
  ("/cabal\\.project\\'" . haskell-cabal-mode))


;; HaskellではTree-sitter版のmajor modeを使用する。
(autoload 'my-haskell-simple-indent-setup "my-haskell-simple-indent")

(use-package haskell-ts-mode
  :vc (:url "https://github.com/dschrempf/haskell-ts-mode")
  :commands haskell-ts-mode
  :hook
  (haskell-ts-mode . my-haskell-simple-indent-setup)
  :init
  (add-to-list 'major-mode-remap-alist
               '(haskell-mode . haskell-ts-mode)))

;; .editorconfig の indent_size を軽量インデントの幅へ反映する。
(with-eval-after-load 'editorconfig
  (add-to-list 'editorconfig-indentation-alist
               '(haskell-ts-mode my-haskell-simple-indent-offset)))


;;; PHP -------------------------------------------------------------

;; PHPではEmacs標準のTree-sitter modeを使用する。
(use-package php-ts-mode
  :ensure nil
  :commands php-ts-mode)


;;; LSP -------------------------------------------------------------


(declare-function diff-hl-mode "diff-hl" (&optional arg))


(defun my/diff-hl-enable-after-lsp-open ()
  "TRAMP先ではLSP接続完了後にdiff-hlを有効にする。"
  (when (and buffer-file-name
             (file-remote-p buffer-file-name))
    (diff-hl-mode 1)))


;; Language Server Protocolを利用する。
(use-package lsp-mode
  :ensure t
  :commands lsp-deferred
  :hook
  ((lua-ts-mode . lsp-deferred)
   (haskell-ts-mode . lsp-deferred)
   (php-ts-mode . lsp-deferred)
   (python-ts-mode . lsp-deferred)
   (typescript-ts-mode . lsp-deferred)
   (tsx-ts-mode . lsp-deferred)
   ;; TRAMP先ではLSP接続後にdiff-hlを有効にする。
   (lsp-after-open . my/diff-hl-enable-after-lsp-open)
   (lsp-mode . lsp-enable-which-key-integration))

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
  (lsp-headerline-breadcrumb-enable nil)
  :bind
  (:map lsp-mode-map
	("<f12>" . lsp-find-definition)
	("S-<f12>" . lsp-find-references)
	("S-s-m" . my/lsp-problems))
  (:map my/lsp-problems-mode-map
	("S-s-m" . my/lsp-problems))

  :config
  ;; HLSのcompletionItem/resolveでfalseがnullへ変換されるのを防ぐ。
  ;; lsp-mode本体にもrust-analyzer向けの同種の補正がある。
  (advice-add #'lsp-completion--fix-resolve-data
              :after
              #'my/lsp-completion-fix-haskell-resolve-data)

  ;; ProblemsバッファをLSP診断の更新に追従させる。
  (add-hook 'lsp-diagnostics-updated-hook
            #'my/lsp-problems-refresh-if-open))


;; TypeScriptはプロジェクトにインストールされたTypeScriptを優先する。
(with-eval-after-load 'lsp-javascript
  (setopt lsp-clients-typescript-prefer-use-project-ts-server t))


;; Python Language ServerとしてPyrightを使用する。
(use-package lsp-pyright
  :ensure t
  :after lsp-mode
  :custom
  ;; .venv / venv がなければPATH上のpython3を使用する。
  (lsp-pyright-python-executable-cmd "python3"))


;; Haskell Language Serverを使用する。
(use-package lsp-haskell
  :ensure t
  :after lsp-mode
  :custom
  ;; HLSから明示的に整形した場合もFourmoluを使用する。
  (lsp-haskell-formatting-provider "fourmolu")

  ;; HLS内蔵版ではなくPATH上のFourmoluを使用する。
  ;; Apheleiaと同じ実行ファイルを使うことで整形結果の差を防ぐ。
  (lsp-haskell-plugin-fourmolu-config-external t)

  :config
  ;; ファイル末尾の空行でnotes hoverが存在しない行を参照し、
  ;; "Line not found in file" を出す問題を避ける。
  ;; notesの補完・定義ジャンプ・参照検索はそのまま利用する。
  (lsp-register-custom-settings
   '(("haskell.plugin.notes.hoverOn" nil t))))


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
  :custom
  ;; TRAMP上ではformatterをリモート側で実行する。
  (apheleia-remote-algorithm 'remote)
  :hook
  ;; 保存時の整形も手動実行と同じApheleiaの設定を使用する。
  ((lua-ts-mode . apheleia-mode)
   (haskell-ts-mode . apheleia-mode)
   (haskell-cabal-mode . apheleia-mode)
   (php-ts-mode . apheleia-mode)
   (python-ts-mode . apheleia-mode)
   (typescript-ts-mode . apheleia-mode)
   (tsx-ts-mode . apheleia-mode))

  :custom
  ;; TRAMP先ではformatterをリモート側で実行する。
  (apheleia-remote-algorithm 'remote)

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

  ;; PythonはRuffで整形する。
  ;; Apheleia標準のRuff formatter定義を使用する。
  (setf (alist-get 'python-ts-mode apheleia-mode-alist)
        'ruff)

  ;; HaskellはFourmoluで整形する。
  ;; 元ファイルの場所を渡し、Fourmoluの設定やCabal情報を正しく探索させる。
  (setf (alist-get 'fourmolu apheleia-formatters)
        '("fourmolu" "--stdin-input-file" filepath))

  ;; haskell-ts-modeでは必ずFourmoluを使用する。
  (setf (alist-get 'haskell-ts-mode apheleia-mode-alist)
        'fourmolu)

  ;; Cabalファイルはcabal-gildで整形する。
  (setf (alist-get 'cabal-gild apheleia-formatters)
	'("cabal-gild"))
  
  (setf (alist-get 'haskell-cabal-mode apheleia-mode-alist)
	'cabal-gild))


;; 手動整形も保存時と同じApheleiaのformatter選択を使用する。
(with-eval-after-load 'lsp-mode
  (keymap-set lsp-command-map "= =" #'apheleia-format-buffer))


(with-eval-after-load 'tramp
  ;; GHCupでインストールしたコマンドをTRAMPから見つけられるようにする。
  (add-to-list 'tramp-remote-path "/root/.ghcup/bin"))


;;; Database --------------------------------------------------------

;; PostgreSQLへEmacs Lispから直接接続する。
(use-package pgsql
  :ensure t
  :defer t)


;; Emacs内でSQLの実行・DBの閲覧を行う。
(use-package clutch
  :ensure t
  :commands clutch-query-console)


;;; development.el ends here
