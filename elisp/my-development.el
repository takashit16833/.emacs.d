;;; my-development.el --- Development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 開発時に使用する独自コマンドを定義する。

;;; Code:


(require 'cl-lib)


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
(declare-function lsp-completion-at-point "lsp-completion" ())
(declare-function lsp:completion-options-trigger-characters?
                  "lsp-protocol" (completion-options))


(defun my/haskell-lsp-completion-trigger-p ()
  "Point直前がHLSの補完トリガーならnon-nilを返す。"
  (and (derived-mode-p 'haskell-ts-mode)
       (bound-and-true-p lsp-completion-mode)
       (when-let* ((options
                    (lsp--capability-for-method "textDocument/completion"))
                   (triggers
                    (lsp:completion-options-trigger-characters? options)))
         (cl-some
          (lambda (trigger)
            (let ((length (length trigger)))
              (when (<= length
                        (- (point) (line-beginning-position)))
                (and
                 (string=
                  trigger
                  (buffer-substring-no-properties
                   (- (point) length)
                   (point)))
                 trigger))))
          (append triggers nil)))))


(defun my/haskell-lsp-completion--call-capf ()
  "HLS trigger直後だけ空prefixとしてLSP CAPFを呼ぶ。"
  (if (my/haskell-lsp-completion-trigger-p)
      (let ((original-bounds
             (symbol-function 'bounds-of-thing-at-point)))
        ;; lsp-modeはCAPFのbounds開始位置を候補のprefix推測にも使う。
        ;; `Text.' 直後はsymbol boundsが `Text' の先頭を指すため、
        ;; HLSが返す `all' や `pack' と `Text.' が比較され全候補が落ちる。
        ;; trigger直後だけsymbol boundsを空範囲にする。
        (cl-letf (((symbol-function 'bounds-of-thing-at-point)
                   (lambda (thing)
                     (if (eq thing 'symbol)
                         (cons (point) (point))
                       (funcall original-bounds thing)))))
          (lsp-completion-at-point)))
    (lsp-completion-at-point)))


(defun my/haskell-lsp-completion-at-point ()
  "HLSのLSP CAPFを入力変更ごとに再評価できるtableへ包む。"
  ;; lsp-modeのCAPFは同じcompletion session内で最初のresultを再利用する。
  ;; Capeのbusterで入力変更を検出し、同じtableを新しいprefixで再評価する。
  (cape-wrap-buster #'my/haskell-lsp-completion--call-capf))


(defun my/haskell-lsp-completion-reset-on-trigger ()
  "HLSの補完トリガー入力時に古い補完セッションを終了する。"
  (when (and (my/haskell-lsp-completion-trigger-p)
             (bound-and-true-p completion-in-region-mode))
    ;; `Text' で始まったセッションはboundsがtrigger前を指しているため、
    ;; `Text.' では一度終了し、空prefixの新しいセッションを開始させる。
    (completion-in-region-mode -1)))


(defun my/haskell-lsp-completion-setup ()
  "Haskellでは標準LSP CAPFをqualified completion対応版へ差し替える。"
  ;; minor modeの再設定時にも重複を残さない。
  (remove-hook 'completion-at-point-functions
               #'my/haskell-lsp-completion-at-point t)
  (remove-hook 'post-self-insert-hook
               #'my/haskell-lsp-completion-reset-on-trigger t)

  (when (and (derived-mode-p 'haskell-ts-mode)
             (bound-and-true-p lsp-completion-mode))
    (remove-hook 'completion-at-point-functions
                 #'lsp-completion-at-point t)
    (add-hook 'completion-at-point-functions
              #'my/haskell-lsp-completion-at-point nil t)
    (add-hook 'post-self-insert-hook
              #'my/haskell-lsp-completion-reset-on-trigger nil t)))


(defun my/diff-hl-enable-after-lsp-open ()
  "TRAMP先ではLSP接続完了後にdiff-hlを有効にする。"
  (when (and buffer-file-name
             (file-remote-p buffer-file-name))
    (diff-hl-mode 1)))


(provide 'my-development)

;;; my-development.el ends here
