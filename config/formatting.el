;;; formatting.el --- Code formatting configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; LSPとApheleiaを使い分けて、各言語の整形を設定する。

;;; Code:

;; TRAMP上では外部フォーマッタをApheleia経由で呼ぶと、一時ファイルの
;; 転送往復が増えて保存が遅くなる場合がある。言語サーバーが十分な整形
;; 機能を提供する言語はLSP経由を優先し、それ以外はApheleiaを使う。
;; 現時点では実測で差が確認できたHaskellだけをLSP整形の対象にする。
(defvar my/eglot-format-on-save-modes '(haskell-ts-mode)
  "保存時にEglot経由で整形するmajor mode。")

(declare-function eglot-managed-p "eglot" ())

(defun my/eglot-format-on-save-setup ()
  "対象モードではEglot接続中だけ保存時整形を有効にする。"
  (when (memq major-mode my/eglot-format-on-save-modes)
    (if (eglot-managed-p)
        (add-hook 'before-save-hook #'eglot-format-buffer nil t)
      (remove-hook 'before-save-hook #'eglot-format-buffer t))))

(with-eval-after-load 'eglot
  (add-hook 'eglot-managed-mode-hook #'my/eglot-format-on-save-setup))

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

  ;; Cabalファイルはcabal-gildで整形する。
  (setf (alist-get 'cabal-gild apheleia-formatters)
	'("cabal-gild"))

  (setf (alist-get 'haskell-cabal-mode apheleia-mode-alist)
	'cabal-gild))


;;; formatting.el ends here
