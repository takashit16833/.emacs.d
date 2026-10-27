;;; languages.el --- Programming language configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; 言語ごとのmajor mode、補助コマンド、インデントを設定する。

;;; Code:

;; 遅延読み込みするパッケージの変数をコンパイラに宣言する。
(defvar haskell-ts-inferior-mode-map)
(defvar editorconfig-indentation-alist)
(defvar markdown-ts-mode-map)


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

;; JSONではEmacs標準のTree-sitter modeを使用する。
(use-package json-ts-mode
  :ensure nil
  :mode ("\\.json\\'" . json-ts-mode))

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


;;; Markdown

;; Visual Line の折り返しで日本語と英語の混在文を自然に扱う。
;; setopt は kinsoku も読み込む（Emacs 31.1）。
(setopt word-wrap-by-category t)

(use-package markdown-ts-mode
  :ensure nil
  :mode ("\\.md\\'" . markdown-ts-mode)
  :custom
  (markdown-ts-hide-markup t)
  ;; Org の箇条書きと同じ記号を深さによらず使う。
  (markdown-ts-unordered-list-marker '(("• " . "• "))))


(use-package markdown-ts-appear
  :ensure t
  :hook (markdown-ts-mode . markdown-ts-appear-mode)
  :custom
  ;; Org と同じ縦線を見出し記号に使う。色はテーマ側の face に任せる。
  (markdown-ts-appear-heading-bullets
   (list (propertize "┃" 'face 'markdown-ts-delimiter)))
  ;; 表は画面幅に合わせて描画・折り返す。交互の行背景は使わない。
  (markdown-ts-appear-table-style 'wrapped)
  (markdown-ts-appear-table-zebra-stripe nil))


;; 引用の本文と記号は Org のコメントブロックと配色を共通にする。
;; 色指定はテーマ側の my/org-block-comment に任せる。
(with-eval-after-load 'markdown-ts-mode
  (set-face-attribute 'markdown-ts-block-quote nil
                      :inherit 'my/org-block-comment))
(with-eval-after-load 'markdown-ts-appear
  (set-face-attribute 'markdown-ts-appear-block-quote-marker nil
                      :inherit 'my/org-block-comment-delimiter))

(use-package markdown-indent-mode
  :ensure t
  :hook (markdown-ts-mode . markdown-indent-mode))

;; 閲覧モードではカーソル移動による記号の再表示を止める。
;; 他のMarkdown用hookが動いた後に実行する。
(autoload 'my/markdown-enable-reading "my-markdown")
(autoload 'my/markdown-toggle-mode "my-markdown" nil t)
(autoload 'my/markdown-table-align "my-markdown-table" nil t)
(autoload 'my/markdown-table-setup "my-markdown-table")
(add-hook 'markdown-ts-mode-hook #'my/markdown-enable-reading 90)

;; 閲覧／編集を同じキーで切り替える。
(with-eval-after-load 'markdown-ts-mode
  (keymap-set markdown-ts-mode-map
              "s-e" #'my/markdown-toggle-mode)
  ;; C-c C-c は表内だけで変更し、それ以外の標準操作を維持する。
  (my/markdown-table-setup))


;; Go

(use-package go-ts-mode
  :ensure nil
  :mode "\\.go\\'"
  :custom
  (go-ts-indent-offset 4))


;;; languages.el ends here
