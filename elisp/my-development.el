;;; my-development.el --- Development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 開発時に使用する独自コマンドを定義する。

;;; Code:


(defun my/flymake-diagnostic-type-label (diagnostic)
  "DIAGNOSTICの種類を色付きの表示用文字列にする。"
  (pcase (flymake-diagnostic-type diagnostic)
    (:error
     (propertize "[ERROR]" 'face 'flymake-error-echo))
    (:warning
     (propertize "[WARNING]" 'face 'flymake-warning-echo))
    (:note
     (propertize "[NOTE]" 'face 'flymake-note-echo))
    (type
     (format "[%s]" type))))


(defun my/flymake-format-diagnostic (diagnostic)
  "DIAGNOSTICを表示用文字列にする。"
  (concat
   (my/flymake-diagnostic-type-label diagnostic)
   " "
   (flymake-diagnostic-text diagnostic)))


(defun my/lsp-completion-fix-haskell-resolve-data (item)
  "HLSへ返す補完候補ITEMのfalse値をJSON falseとして保持する。"
  (let ((data (lsp:completion-item-data? item)))
    ;; HLSのitemNeedsTypeはBoolだが、Emacs LispのnilをそのままJSON化すると
    ;; nullになるため、completionItem/resolveでHLSのデコードに失敗する。
    (when (and (lsp-member? data :itemNeedsType)
               (null (lsp-get data :itemNeedsType)))
      (lsp-put data :itemNeedsType :json-false))))


;; HLS qualified completion workaround -------------------------------------

(declare-function lsp--capability-for-method "lsp-mode" (method))
(declare-function lsp:completion-options-trigger-characters?
                  "lsp-protocol" (completion-options))
(declare-function lsp-completion--looking-back-trigger-characterp
                  "lsp-completion" (trigger-characters))
(declare-function lsp-completion--clear-cache
                  "lsp-completion" (&optional keep-last-result))


(defun my/haskell-lsp-completion-trigger-p ()
  "Point直前がHLSの補完トリガーならnon-nilを返す。"
  (and (derived-mode-p 'haskell-ts-mode)
       (when-let* ((options
                    (lsp--capability-for-method "textDocument/completion"))
                   (triggers
                    (lsp:completion-options-trigger-characters? options)))
         (lsp-completion--looking-back-trigger-characterp triggers))))


(defun my/haskell-lsp-completion-fix-empty-prefix (start)
  "HLSの補完トリガー直後でSTARTがnilならpointを返す。

lsp-modeは補完候補からprefix開始位置を推測できない場合、
CAPFのbounds開始位置へフォールバックする。HLSの `Text.' 補完では
候補が `all' や `pack' のように返るため、そのfallbackでは
`Text.' が検索文字列になり全候補が除外される。

HLSが宣言した補完トリガー直後に限り、空prefixとして現在位置を使う。"
  (or start
      (when (my/haskell-lsp-completion-trigger-p)
        (point))))


(defun my/haskell-lsp-completion-reset-on-trigger ()
  "HLSの補完トリガー入力時に古い補完セッションとcacheを破棄する。"
  (when (my/haskell-lsp-completion-trigger-p)
    ;; `Text' で始まった補完セッションを `Text.' まで継続すると、
    ;; lsp-modeはtrigger前の候補を再利用するため一度終了する。
    (when (bound-and-true-p completion-in-region-mode)
      (completion-in-region-mode -1))

    ;; bounds開始位置がtrigger前後で同じ場合でも再問い合わせさせる。
    (lsp-completion--clear-cache)))


(defun my/haskell-lsp-completion-setup ()
  "HLSのqualified completion workaroundを現在バッファへ設定する。"
  (if (and (derived-mode-p 'haskell-ts-mode)
           (bound-and-true-p lsp-completion-mode))
      (add-hook 'post-self-insert-hook
                #'my/haskell-lsp-completion-reset-on-trigger nil t)
    (remove-hook 'post-self-insert-hook
                 #'my/haskell-lsp-completion-reset-on-trigger t)))


(defun my/diff-hl-enable-after-lsp-open ()
  "TRAMP先ではLSP接続完了後にdiff-hlを有効にする。"
  (when (and buffer-file-name
             (file-remote-p buffer-file-name))
    (diff-hl-mode 1)))


(provide 'my-development)

;;; my-development.el ends here
