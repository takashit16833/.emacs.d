;;; languages.el --- Programming language configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; 言語ごとのmajor mode、補助コマンド、インデントを設定する。

;;; Code:

;; 遅延読み込みするパッケージの変数をコンパイラに宣言する。
(defvar haskell-ts-inferior-mode-map)
(defvar editorconfig-indentation-alist)


;; PythonではEmacs標準のTree-sitter modeを使用する。
;; Emacs 31.1では `treesit-enabled-modes' が
;; `major-mode-remap-alist' への反映を管理する。
(setopt treesit-enabled-modes '(python-ts-mode))

;;; Lua

;; LuaでTree-sitterを使用する。
(use-package lua-ts-mode
  :ensure nil
  :mode ("\\.lua\\'" . lua-ts-mode))


;;; Haskell

(autoload 'my/haskell-ghci-complete "my-haskell-ghci" nil t)
(autoload 'my/haskell-ghci-completion-setup "my-haskell-ghci")

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


;;; PHP

;; PHPではEmacs標準のTree-sitter modeを使用する。
(use-package php-ts-mode
  :ensure nil
  :commands php-ts-mode)


;;; JSON / jq

(autoload 'my/jq-playground "my-jq" nil t)

;; jqスクリプトの編集と、JSONに対するjqの対話的実行。
(use-package jq-mode
  :ensure t
  :commands (jq-mode jq-interactively)
  :mode ("\\.jq\\'" . jq-mode)
  :custom
  ;; Emacs標準のJSONモードで結果を色分けする。
  (jq-interactive-font-lock-mode #'js-json-mode))


;;; Yaml

(use-package yaml-ts-mode
  :ensure nil
  :hook (yaml-ts-mode . eglot-ensure))


;;; languages.el ends here
