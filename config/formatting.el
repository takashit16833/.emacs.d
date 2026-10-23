;;; formatting.el --- Code formatting configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Apheleiaと各言語の外部フォーマッタを設定する。

;;; Code:

;; 外部フォーマッタを非同期で実行する。
(use-package apheleia
  :ensure t
  :custom
  ;; TRAMP上ではformatterをリモート側で実行する。
  (apheleia-remote-algorithm 'remote)
  :hook
  ;; 保存時の整形も手動実行と同じApheleiaの設定を使用する。
  ((js-json-mode . apheleia-mode)
   (yaml-ts-mode . apheleia-mode)
   (lua-ts-mode . apheleia-mode)
   (haskell-ts-mode . apheleia-mode)
   (haskell-cabal-mode . apheleia-mode)
   (php-ts-mode . apheleia-mode)
   (python-ts-mode . apheleia-mode)
   (typescript-ts-mode . apheleia-mode)
   (tsx-ts-mode . apheleia-mode))

  :config
  ;; JSONはjqで整形する。
  ;; Apheleiaの既定値はPrettierなので、JSONだけjqへ切り替える。
  (setf (alist-get 'js-json-mode apheleia-mode-alist)
        'jq)

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

  ;; PythonのフォーマッタにはBlackではなくRuffを使用する。
  (setf (alist-get 'python-ts-mode apheleia-mode-alist)
	'ruff)

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


;;; formatting.el ends here
