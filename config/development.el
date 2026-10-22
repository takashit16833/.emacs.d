;;; development.el --- Development configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; 複数言語で共有する診断、補完、説明表示の設定を置く。

;;; Code:

;; Tree-sitterは必要になるまで読み込まず、変数だけ宣言する。
(defvar treesit-font-lock-level)

;; Tree-sitterの色分けを最大レベル（４が最大）。
(setq treesit-font-lock-level 3)

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


;;; Eglot

;; 遅延読み込みするライブラリの関数をコンパイラへ宣言する。
(declare-function eglot-completion-at-point "eglot" ())
(declare-function my/eglot-haskell-qualified-completion
                  "my-eglot" (original &rest args))
(declare-function my/eglot-haskell-completion-command "my-eglot" (capf))

(autoload 'my/eglot-python-server "my-python")

;; Language Serverとの通信はEmacs標準のEglotに任せる。
;; 補完・診断・定義ジャンプはCorfu・Flymake・Xrefと連携する。
(use-package eglot
  :ensure nil
  :bind
  (:map eglot-mode-map
        ("C-c l a" . my/eglot-code-actions)
        ("C-c l i" . my/eglot-apply-inlay-hint))
  :hook
  ((lua-ts-mode . eglot-ensure)
   (haskell-ts-mode . eglot-ensure)
   (php-ts-mode . eglot-ensure)
   (python-ts-mode . eglot-ensure)
   (typescript-ts-mode . eglot-ensure)
   (tsx-ts-mode . eglot-ensure)
   ;; EglotがCAPFを設定し終わった段階で、dabbrevとの統合を切り替える。
   (eglot-managed-mode . my/eglot-dabbrev-completion-setup)
   ;; TRAMPではEglot接続後にdiff-hlを有効にする。
   (eglot-managed-mode . my/eglot-enable-remote-diff-hl))
  :custom
  ;; 全言語でLSPによる色分けを使わず、各major modeの配色を優先する。
  (eglot-ignored-server-capabilities '(:semanticTokensProvider))
  :init
  ;; HLSの標準上限40件では、TRAMPでT.unからunpackが候補から漏れた。
  ;; 200件に増やすと候補が表示されることを実機で確認済み。
  ;; default値なので、必要ならプロジェクトの.dir-locals.elで上書きできる。
  (setq-default eglot-workspace-configuration
                '(:haskell (:maxCompletions 200)))
  :config
  ;; Eglot標準のPHP候補にはintelephenseがないため追加する。
  ;; 他の言語サーバーはEmacs 31.1の標準定義をそのまま使用する。
  (dolist (entry
           '((php-ts-mode . ("intelephense" "--stdio"))
             (python-ts-mode . my/eglot-python-server)))
    (add-to-list 'eglot-server-programs entry))
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

;;; development.el ends here
