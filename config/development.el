;;; development.el --- Development configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; プログラミング、Git、言語固有の開発設定を置く。

;;; Code:


(require 'my-development)


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
  ;; 旧Problemsと同じキーで、診断メッセージの全文一覧を開く。
  ;; UIの実装はコマンドを初めて使うまで読み込まない。
  :init
  (autoload 'my/flymake-problems "my-flymake-problems" nil t)
  :bind ("S-s-m" . my/flymake-problems)
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

;; Haskell REPLのキーマップはhaskell-ts-repl読込後に定義されるため、
;; 読み込みが完了してからTABの割り当てを追加する。
(with-eval-after-load 'haskell-ts-repl
  ;; REPL内のTABだけをGHCi補完コマンドへ割り当てる。
  (keymap-set haskell-ts-inferior-mode-map
              "TAB" #'my/haskell-ghci-complete)
  ;; REPLバッファが作られるたびに、補完フックとCorfuを準備する。
  (add-hook 'haskell-ts-inferior-mode-hook
            #'my/haskell-ghci-completion-setup))


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


;;; Eglot -----------------------------------------------------------

;; Language Serverとの通信はEmacs標準のEglotに任せる。
;; 補完・診断・定義ジャンプはCorfu・Flymake・Xrefと連携する。
(use-package eglot
  :ensure nil
  :bind
  (:map eglot-mode-map
        ("C-c l a" . my/eglot-code-actions))
  :hook
  ((lua-ts-mode . eglot-ensure)
   (haskell-ts-mode . eglot-ensure)
   (php-ts-mode . eglot-ensure)
   (python-ts-mode . eglot-ensure)
   (typescript-ts-mode . eglot-ensure)
   (tsx-ts-mode . eglot-ensure)
   ;; EglotがCAPFを設定し終わった段階で、dabbrevとの統合を切り替える。
   (eglot-managed-mode . my/eglot-dabbrev-completion-setup)
   ;; Eglotは接続後にSemantic Tokensを有効化する。
   ;; HaskellだけTree-sitterの配色に戻す（他言語には影響させない）。
   (eglot-managed-mode . my/eglot-haskell-disable-semantic-tokens))
  :init
  ;; HLSの標準上限40件では、TRAMPでT.unからunpackが候補から漏れた。
  ;; 200件に増やすと候補が表示されることを実機で確認済み。
  ;; default値なので、必要ならプロジェクトの.dir-locals.elで上書きできる。
  (setq-default eglot-workspace-configuration
                '(:haskell (:maxCompletions 200)))
  :config
  ;; Eglot標準のPHP候補にはintelephenseがないため追加する。
  ;; 他の言語サーバーはEmacs 31.1の標準定義をそのまま使用する。
  (add-to-list 'eglot-server-programs
               '(php-ts-mode . ("intelephense" "--stdio")))

  ;; HLSの自動import補完をEglot 31.1で成立させるための互換処理。
  ;; enc → encodeだけが挿入され、import Data.Aeson (encode)が追加されない
  ;; 不具合への対応。原因・Eglot/HLSのソース・削除条件はmy-eglot.elを参照。
  ;; Eglot本体がCompletionItem.commandに対応したら二重実行を避けて撤去する。
  (require 'my-eglot)
  ;; T.unpを1つのsymbolとして扱う場合、unpackが候補表に存在しても
  ;; 不一致として除外される。Haskellの修飾名のboundsだけ補正する。
  ;; 自動import補完のadviceとは原因が異なるため独立させる。
  (unless (advice-member-p #'my/eglot-haskell-qualified-completion
                           #'eglot-completion-at-point)
    (advice-add #'eglot-completion-at-point :around
                #'my/eglot-haskell-qualified-completion))
  (unless (advice-member-p #'my/eglot-haskell-completion-command
                           #'eglot-completion-at-point)
    (advice-add #'eglot-completion-at-point :filter-return
                #'my/eglot-haskell-completion-command)))


;; ElDocの説明をchild frameで表示する。
(use-package eldoc-box
  :ensure t
  :bind ("C-c h" . eldoc-box-help-at-point)
  :config
  ;; TTY child frameの角丸枠を表示する。
  (setf (alist-get 'undecorated eldoc-box-frame-parameters)
        nil)

  ;; child frame自体の背景色をCorfuと合わせる。
  (setf (alist-get 'background-color eldoc-box-frame-parameters)
        (face-attribute 'corfu-default :background nil 'default)))


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

  ;; Pythonはプロジェクト内のRuffを優先する。
  ;; 存在しない場合はPATH上のRuffを使用する。
  (setcar (alist-get 'ruff apheleia-formatters)
          '(let* ((project (project-current nil))
                  (local-ruff
                   (when project
                     (expand-file-name ".venv/bin/ruff"
                                       (project-root project)))))
             (if (and local-ruff (file-executable-p local-ruff))
		 local-ruff
               "ruff")))

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


(with-eval-after-load 'tramp
  ;; GHCupでインストールしたコマンドをTRAMPから見つけられるようにする。
  (add-to-list 'tramp-remote-path "/root/.ghcup/bin"))



;;; JSON / jq -------------------------------------------------------

;; jqスクリプトの編集と、JSONに対するjqの対話的実行。
(use-package jq-mode
  :ensure t
  :commands (jq-mode jq-interactively)
  :mode ("\\.jq\\'" . jq-mode)
  :custom
  ;; Emacs標準のJSONモードで結果を色分けする。
  (jq-interactive-font-lock-mode #'js-json-mode))


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
