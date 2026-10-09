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
  (when-let* ((data (lsp:completion-item-data? item))
              (value (lsp-get data :resolveValue)))
    ;; ghcideのitemNeedsTypeはresolveValue内のBool。
    ;; nilのまま送信するとJSON nullになり、HLSがresolveに失敗する。
    (when (and (equal (lsp-get data :resolvePlugin)
                      "ghcide-completions")
               (lsp-member? value :itemNeedsType)
               (null (lsp-get value :itemNeedsType)))
      (lsp-put value :itemNeedsType :json-false))))


;; Pythonプロジェクトの仮想環境をEmacsから利用できるようにする。
(defun my/python-setup-venv ()
  (unless (file-remote-p default-directory)
    (let ((root (locate-dominating-file default-directory ".venv")))
      (when root
        (let ((bin (expand-file-name ".venv/bin" root)))
          (when (file-directory-p bin)
            (setq-local exec-path (cons bin exec-path))))))))


;; GHCiの補完候補をEmacsのcompletion-at-pointへ渡す。
(defun my/haskell-ghci-completion-at-point ()
  "GHCiの :complete repl を使って入力を補完する。"
  (when (and (get-buffer-process (current-buffer))
	     (comint-after-pmark-p))
    (let* ((input-start (comint-line-beginning-position))
	   (end (point))
	   (input (buffer-substring-no-properties
		   input-start end))
	   (results
	    (comint-redirect-results-list
	     (format ":complete repl %S" input)
	     "^\\(?:[0-9]+ [0-9]+ \\)?\"\\(.*\\)\"\\r?$"
	     1))
	   ;; 先頭行は補完対象外の接頭部分。
	   (unused (car results))
	   (candidates (cdr results))
	   (start (and unused
		       (+ input-start (length unused)))))
      (when (and start candidates (<= start end))
	(list start end candidates)))))


(defun my/haskell-ghci-completion-setup ()
  "Haskell REPLの補完候補にGHCiを追加する。"
  (add-hook 'completion-at-point-functions
            #'my/haskell-ghci-completion-at-point
            nil t))


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


;;; Docker/TRAMP LSP transport ---------------------------------------------
;;
;; lsp-modeのstdio接続はLSPのContent-Lengthをバイト数として扱うため、
;; 'make-process'へ :coding 'no-conversion を指定している。
;;
;; しかしEmacs 31.1の通常のDocker/TRAMP経路では、LSPプロセスが
;; /bin/sh -i 経由かつ utf-8-unix で作られ、受信データがlsp-modeへ
;; 渡る前に文字列として復号される。実際にHLSの診断で
;; Content-Length=3570に対してJSON parserへ3546 bytesしか渡らず、
;; JSON末尾が途中で切れて 'json-end-of-file' になることを確認した。
;;
;; TRAMPのdirect asyncを使うと 'docker exec' からLanguage Serverを
;; 直接起動でき、lsp-modeが要求した no-conversion が維持される。
;; ただしEmacs 31.1のDocker methodは通常接続用に "-it" を固定で持ち、
;; 非TTYのdirect asyncではDockerが起動を拒否する。そのためLSPの起動中だけ
;; 'tramp-methods' のコピー上で "-it" を "-i" に変更する。
;;
;; Docker/TRAMP全体へdirect asyncを有効化するとMagit、compile、Apheleia等へ
;; 影響し得るため、専用connection-local application 'my-lsp' と
;; 'lsp--start-workspace' adviceでLSP起動時だけに限定している。
;;
;; 'lsp--start-workspace' はlsp-modeの内部APIなので、lsp-modeまたはTRAMP側で
;; 通常経路がバイト透過になった場合は、このworkaround自体を削除できないか
;; 再確認すること。


(defvar connection-local-default-application)
(defvar tramp-methods)

(declare-function diff-hl-mode "diff-hl" (&optional arg))


(defun my/lsp-docker-direct-async-methods (methods)
  "METHODSをコピーし、DockerのLSP用login argsからTTY割り当てを外す。"
  (let ((copy (copy-tree methods)))
    (when-let* ((method (assoc "docker" copy))
                (login-args (assq 'tramp-login-args (cdr method))))
      (setcar
       (cdr login-args)
       (mapcar
        (lambda (args)
          (if (equal args '("-it"))
              '("-i")
            args))
        (cadr login-args))))
    copy))


(defun my/lsp-start-workspace-with-docker-direct-async
    (original session client root &optional initialization-options)
  "Docker上のLSP workspaceだけdirect asyncで起動する。"
  (if (equal (file-remote-p root 'method) "docker")
      (let ((default-directory root)
            (connection-local-default-application 'my-lsp)
            (tramp-methods
             (my/lsp-docker-direct-async-methods tramp-methods)))
        (funcall original session client root initialization-options))
    (funcall original session client root initialization-options)))


(defun my/lsp-enable-docker-direct-async ()
  "Docker/TRAMP上のLSPをバイト透過なdirect async経路で起動する。"
  (connection-local-set-profile-variables
   'my/lsp-docker-direct-async
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application my-lsp :protocol "docker")
   'my/lsp-docker-direct-async)
  (unless (advice-member-p
           #'my/lsp-start-workspace-with-docker-direct-async
           #'lsp--start-workspace)
    (advice-add #'lsp--start-workspace
                :around
                #'my/lsp-start-workspace-with-docker-direct-async)))


(defun my/diff-hl-enable-after-lsp-open ()
  "TRAMP先ではLSP接続完了後にdiff-hlを有効にする。"
  (when (and buffer-file-name
             (file-remote-p buffer-file-name))
    (diff-hl-mode 1)))


(provide 'my-development)

;;; my-development.el ends here
