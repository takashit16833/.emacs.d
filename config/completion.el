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


(use-package dabbrev
  :ensure nil
  :custom
  ;; バッファ内の単語は元の大文字小文字を保持する。
  (dabbrev-case-replace nil))


;; LSP補完をCorfuから利用し、候補がない場合だけdabbrevへフォールバックする。
;;
;; lsp-modeはqualified completion（例: Text.unp -> unpack）のために
;; lsp-capf / lsp-passthroughという専用の補完カテゴリを使用する。
;; cape-capf-superでLSPとdabbrevを統合するとカテゴリがcape-superへ変わり、
;; この専用処理が失われるため、LSPはsuper CAPFへ入れない。
(defvar-local my/lsp-completion-capf nil
  "現在バッファで使用するLSP補完用CAPF。")

(defvar-local my/lsp-completion-trigger-characters nil
  "現在のLanguage Serverが宣言した補完トリガー文字。")

(declare-function corfu-quit "corfu" ())
(declare-function lsp--capability-for-method "lsp-mode" (method))
(declare-function lsp-completion--clear-cache "lsp-completion"
                  (&optional keep-last-result))
(declare-function lsp:completion-options-trigger-characters?
                  "lsp-protocol" (completion-options))

(defun my/lsp-completion-update-trigger-characters ()
  "Language Serverが宣言した補完トリガー文字を記録する。"
  (setq my/lsp-completion-trigger-characters
        (when-let* ((options
                     (lsp--capability-for-method "textDocument/completion"))
                    (triggers
                     (lsp:completion-options-trigger-characters? options)))
          (append triggers nil))))

(defun my/lsp-completion-trigger-character-p ()
  "直前に挿入した文字がLSP補完トリガーならnon-nilを返す。"
  (and (bound-and-true-p lsp-completion-mode)
       (> (point) (point-min))
       (seq-contains-p my/lsp-completion-trigger-characters
                       (char-to-string (char-before))
                       #'string=)))

(defun my/lsp-completion-reset-on-trigger ()
  "LSP補完トリガー入力時に新しい補完セッションを開始する。"
  (when (my/lsp-completion-trigger-character-p)
    ;; Teの候補を表示中にText.まで入力した場合などは、
    ;; それまでの文脈を使っているCorfuセッションを終了する。
    (when (and (bound-and-true-p corfu-mode)
               (bound-and-true-p completion-in-region-mode))
      (corfu-quit))

    ;; lsp-modeは完了済み候補を同じセッションで再利用するため、
    ;; Language Server自身が宣言したtrigger characterでは破棄する。
    (lsp-completion--clear-cache)

    ;; trigger characterは補完開始イベントなので、corfu-autoの
    ;; 遅延処理には任せず、その場で新しいLSP文脈の補完を開始する。
    (completion-at-point)))

(defun my/lsp-completion-setup ()
  "CorfuでLSP補完を使用し、候補がない場合はdabbrevへフォールバックする。"
  ;; lsp-completion-modeの再設定時に古いCAPFとhookを残さない。
  (when my/lsp-completion-capf
    (setq-local completion-at-point-functions
                (delq my/lsp-completion-capf
                      completion-at-point-functions))
    (setq my/lsp-completion-capf nil))

  (remove-hook 'post-self-insert-hook
               #'my/lsp-completion-reset-on-trigger t)

  (when lsp-completion-mode
    (require 'dabbrev)
    (my/lsp-completion-update-trigger-characters)

    ;; Corfu単体で補完を開始する場合も、Language Serverが宣言した文字では
    ;; prefix長に関係なく即時起動する。
    (setq-local corfu-auto-trigger
                (apply #'concat my/lsp-completion-trigger-characters))

    ;; busterで入力変更ごとにLSP CAPFを作り直す。
    ;; nonexclusiveにすることで、LSP候補がない場合だけ後段のdabbrevを試す。
    ;; cape-capf-superは使わず、lsp-capfカテゴリをそのまま保持する。
    (setq my/lsp-completion-capf
          (cape-capf-buster
           (cape-capf-nonexclusive #'lsp-completion-at-point)))

    (setq-local completion-at-point-functions
                (cons my/lsp-completion-capf
                      (cons #'dabbrev-capf
                            (delq #'dabbrev-capf
                                  (delq #'lsp-completion-at-point
                                        completion-at-point-functions)))))

    ;; Language Serverが宣言したtrigger character（HLSなら"."など）では
    ;; 古い補完セッションを終了し、その場で新しい文脈の補完を開始する。
    (add-hook 'post-self-insert-hook
              #'my/lsp-completion-reset-on-trigger nil t)))


;; CAPF周りを補助するためのパッケージ。
(use-package cape
  :ensure t
  :after lsp-mode
  :hook
  (lsp-completion-mode . my/lsp-completion-setup))


;;; completion.el ends here
