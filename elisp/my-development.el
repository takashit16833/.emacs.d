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

(declare-function cape-wrap-buster "cape" (capf &optional valid))
(declare-function lsp--capability-for-method "lsp-mode" (method))
(declare-function lsp:completion-options-trigger-characters?
                  "lsp-protocol" (completion-options))
(declare-function lsp-completion--looking-back-trigger-characterp
                  "lsp-completion" (trigger-characters))


(defun my/haskell-lsp-completion-trigger-p ()
  "Point直前がHLSの補完トリガーならnon-nilを返す。"
  (and (derived-mode-p 'haskell-ts-mode)
       (bound-and-true-p lsp-completion-mode)
       (when-let* ((options
                    (lsp--capability-for-method "textDocument/completion"))
                   (triggers
                    (lsp:completion-options-trigger-characters? options)))
         (lsp-completion--looking-back-trigger-characterp triggers))))


(defun my/haskell-lsp-completion--call (function args)
  "FUNCTIONをARGSで呼び、HLS trigger直後だけ空prefixとして扱う。"
  (if (my/haskell-lsp-completion-trigger-p)
      (let ((original-bounds
             (symbol-function 'bounds-of-thing-at-point)))
        ;; lsp-modeはCAPFのbounds開始位置を候補のprefix推測にも使う。
        ;; `Text.' 直後はsymbol boundsが `Text' の先頭を指すため、
        ;; HLSが返す `all' や `pack' と `Text.' が比較され全候補が落ちる。
        ;; trigger直後だけsymbol boundsを空範囲にし、HLSの空prefix補完として扱う。
        (cl-letf (((symbol-function 'bounds-of-thing-at-point)
                   (lambda (thing)
                     (if (eq thing 'symbol)
                         (cons (point) (point))
                       (funcall original-bounds thing)))))
          (apply function args)))
    (apply function args)))


(defun my/haskell-lsp-completion-around (function &rest args)
  "HaskellのLSP CAPFを入力変更ごとに再評価できるtableへ包む。"
  (if (and (derived-mode-p 'haskell-ts-mode)
           (bound-and-true-p lsp-completion-mode))
      ;; lsp-modeのCAPFは一度計算したresultを同じcompletion sessionで
      ;; 再利用する。Capeのbusterで入力変更時だけCAPFを作り直す。
      ;; lsp-mode自身のcompletion cacheは残るため、通常はHLSへ再問い合わせ
      ;; せず、取得済み候補を新しいprefixで絞り込む。
      (cape-wrap-buster
       (lambda ()
         (my/haskell-lsp-completion--call function args)))
    (apply function args)))


(defun my/haskell-lsp-completion-reset-on-trigger ()
  "HLSの補完トリガー入力時に古い補完セッションを終了する。"
  (when (and (my/haskell-lsp-completion-trigger-p)
             (bound-and-true-p completion-in-region-mode))
    ;; `Text' で始まったセッションはboundsがtrigger前を指しているため、
    ;; `Text.' では一度終了し、空prefixの新しいセッションを開始させる。
    (completion-in-region-mode -1)))


(defun my/haskell-lsp-completion-setup ()
  "HLS qualified completion用hookを現在バッファへ設定する。"
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
