;;; my-development.el --- Development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 開発時に使用する独自コマンドを定義する。

;;; Code:


(require 'cl-lib)
(require 'comint)
(require 'subr-x)

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


;;; Haskell REPLで補完機能を有効にする ------------------------------

;; 補完は非同期なので、問い合わせと結果表示の間に状態を覚えておく必要がある。
;; defvar-localにより、別のREPLバッファと状態が混ざらない。
;; pending: GHCiに問い合わせ中の入力（例: ":m +R"）。nilなら待機していない。
;; output-buffer: GHCiの応答を受け取る、画面に表示しない一時バッファ名。
;; cache: 取得済みの (入力文字列 補完開始位置 候補一覧)。
(defvar-local my/haskell-ghci-pending nil)
(defvar-local my/haskell-ghci-output-buffer nil)
(defvar-local my/haskell-ghci-cache nil)

;; GHCiの :complete repl の出力を、Emacsで扱える文字列リストに変換する。
;; 例: 4 4 ":m +" / "Rag.Database" / "Rag.Search" ...
;; 戻り値は (":m +" "Rag.Database" "Rag.Search" ...) の形。
(defun my/haskell-ghci-parse-output (buffer)
  ;; 出力先の一時バッファを読み、REPL本体のカーソル位置は変えない。
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (let (prefix candidates)
        ;; 応答の各行を順番に調べる。
        (while (not (eobp))
          (let ((line
                 (string-trim-right
                  (buffer-substring-no-properties
                   (line-beginning-position)
                   (line-end-position)))))
            (cond
             ;; 最初の「4 4 ":m +"」から、書き換えずに残す部分 ":m +" を読む。
             ;; 正規表現の \( ... \) は、引用符で囲まれた文字列を取り出す範囲。
             ;; read-from-stringの戻り値は (読み取った値 . 終了位置) なのでcarを使う。
             ((string-match
               "\\`[0-9]+ [0-9]+ \\(\".*\"\\)\\'" line)
              (setq prefix
                    (car (read-from-string
                          (match-string 1 line)))))

             ;; 2行目以降の「"Rag.Search"」などを候補として読み取る。
             ;; pushは先頭に追加するため、結果は一時的に逆順になる。
             ((string-match "\\`\".*\"\\'" line)
              (push (car (read-from-string line))
                    candidates))))
          (forward-line 1))
        ;; 先頭行を認識できたときだけ返す。nreverseで候補を元の順序に戻す。
        (when prefix
          (cons prefix (nreverse candidates)))))))

;; 取得済みの候補をEmacs標準の補完形式 (開始位置 終了位置 候補一覧) で返す。
;; GHCiへの問い合わせはここでは行わず、cacheにある結果だけを利用する。
(defun my/haskell-ghci-completion-at-point ()
  (when my/haskell-ghci-cache
    (let ((input (nth 0 my/haskell-ghci-cache))
          (start (nth 1 my/haskell-ghci-cache))
          (candidates (nth 2 my/haskell-ghci-cache)))
      ;; カーソルが現在の入力欄にあり、補完開始位置より後ろにあることを確認。
      ;; 入力の先頭が問い合わせ時と一致する場合だけ候補を使う。
      ;; string-prefix-pなので、末尾への追加入力は許容される点に注意。
      (when (and (comint-after-pmark-p)
                 (<= start (point))
                 (string-prefix-p
                  input
                  (buffer-substring-no-properties
                   (comint-line-beginning-position)
                   (point))))
        ;; この範囲の文字を候補に置き換えるようEmacsに伝える。
        ;; :exclusiveは、この結果が使えるとき他の補完関数に任せない指定。
        (list start (point) candidates
              :exclusive 'yes)))))

;; 応答取得後に補完UIを表示する。通信完了時ではなくタイマーから呼ばれる。
(defun my/haskell-ghci-show-completions (buffer input)
  ;; REPLが閉じられたり、別のバッファへ移動したりしていたら表示しない。
  (when (and (buffer-live-p buffer)
             (eq (window-buffer (selected-window)) buffer))
    (with-current-buffer buffer
      ;; カーソルが入力欄にあり、問い合わせ時の文字列がまだ先頭に残っているか確認。
      ;; 完全一致ではないため、後ろに文字が追加された場合も通過する。
      (when (and (comint-after-pmark-p)
                 (string-prefix-p
                  input
                  (buffer-substring-no-properties
                   (comint-line-beginning-position)
                   (point))))
        ;; cacheを補完候補に変換し、Emacsの補完処理を開始する。
        (completion-at-point)

        ;; タイマーからの実行ではpost-command-hookが走らないため、
        ;; Corfuの候補をここで表示する（内部APIなので更新時には要確認）。
        (when (and (bound-and-true-p corfu-mode)
                   (bound-and-true-p completion-in-region-mode))
          (corfu--exhibit))))))

;; comint-redirect-hookから呼ばれる。GHCiの応答が完了した後の処理。
(defun my/haskell-ghci-completion-finished ()
  ;; 自分たちが補完リクエストを送っているときだけ処理する。
  (when my/haskell-ghci-pending
    (let* ((input my/haskell-ghci-pending)
           (parsed (my/haskell-ghci-parse-output
                    my/haskell-ghci-output-buffer))
           (prefix (car parsed))
           (candidates (cdr parsed))
           (buffer (current-buffer)))
      ;; 応答を受け取ったので「問い合わせ中」を解除し、次のTABを受付可能にする。
      (setq my/haskell-ghci-pending nil)

      ;; 接頭部分と候補が得られ、問い合わせた入力と整合しているか確認。
      (when (and prefix candidates
                 (string-prefix-p prefix input))
        ;; GHCiが返したprefix（例: ":m +"）は残し、その直後から補完する。
        ;; 例: 入力 ":m +R" なら、RだけをRag.Searchなどへ置き換える。
        (setq my/haskell-ghci-cache
              (list input
                    (+ (comint-line-beginning-position)
                       (length prefix))
                    candidates))

        ;; GHCiの出力を処理している途中でUIを開かず、次のタイマー処理に回す。
        ;; 0は「可能になり次第1回だけ」、nilは繰り返しなしの指定。
        (run-at-time
         0 nil
         #'my/haskell-ghci-show-completions
         buffer input)))))

;; TABから呼び出すコマンド。GHCiに問い合わせを送るが、結果はここでは待たない。
(defun my/haskell-ghci-complete ()
  (interactive)
  ;; REPLバッファに紐づいたGHCiプロセスを取得する。
  (let ((process (get-buffer-process (current-buffer))))
    (cond
     ;; 次のいずれかならGHCiへの問い合わせはできない。
     ;; ・processがnil: このバッファにはGHCiプロセスがない。
     ;; ・process-live-pがnil: プロセスはすでに終了している。
     ;; ・comint-after-pmark-pがnil: 現在の入力欄ではなく過去の出力上にいる。
     ;; この場合はGHCiへ送信せず、Emacs標準の補完へ任せる。
     ((not (and process
                (process-live-p process)
                (comint-after-pmark-p)))
      (completion-at-point))

     ;; 先に送った問い合わせが処理中なら、重複して送信しない。
     ;; 1つのGHCiプロセスから返る結果を取り違えないため。
     (my/haskell-ghci-pending
      (message "GHCiの補完応答を待っています"))

     ;; 上のどちらでもなければ、新しい補完問い合わせを開始する。
     (t
      ;; プロンプト（ghci>）を除いた、カーソル直前までの入力を取得する。
      (let ((input (buffer-substring-no-properties
                    (comint-line-beginning-position)
                    (point))))
        ;; 問い合わせ中の入力を保存し、前回の候補を破棄する。
        ;; 結果はREPL本体ではなく、先頭が空白の非表示用バッファで受け取る。
        (setq my/haskell-ghci-pending input
              my/haskell-ghci-cache nil
              my/haskell-ghci-output-buffer
              (format " *GHCi Completion: %s*"
                      (buffer-name)))

	;; 前回の補完結果が混ざらないよう、一時バッファを空にする。
	(with-current-buffer
	    (get-buffer-create my/haskell-ghci-output-buffer)
	  (erase-buffer))
	
        ;; 例: inputが":m +R"なら :complete repl ":m +R" を送信する。
        ;; %Sは引用符やエスケープを含めて文字列を印字する。
        ;; 応答待ちはしない。nilは元のREPLへの出力反映なし、
        ;; 最後のtは出力先の一時バッファを画面に表示しない指定。
        ;; GHCiの次のプロンプトを検出するとcomint-redirect-hookが呼ばれる。
        (comint-redirect-send-command-to-process
         (format ":complete repl %S" input)
         my/haskell-ghci-output-buffer
         process nil t))))))

;; REPL起動時に、候補提供関数と通信完了時の処理を登録する。
(defun my/haskell-ghci-completion-setup ()
  "Haskell REPLの補完機能を有効にする。"
  ;; nil tの最後のtにより、このバッファだけにフックを追加する。
  (add-hook 'completion-at-point-functions
            #'my/haskell-ghci-completion-at-point
            nil t)
  ;; GHCiの応答が最後まで届いたら、解析と表示予約を行う。
  (add-hook 'comint-redirect-hook
            #'my/haskell-ghci-completion-finished
            nil t)

  ;; REPLでは手動TAB補完に限定し、候補を勝手に選択・挿入しない。
  ;; setq-localなので通常のソース編集用Corfu設定は変更しない。
  (setq-local corfu-auto nil
              corfu-preselect 'prompt
              corfu-preview-current nil)

  ;; Haskell REPLはprog-modeではないため、明示的にCorfuを有効化する。
  (corfu-mode 1))


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



;;; TRAMP LSP paths --------------------------------------------------------
;;
;; Emacs 31.1のexecutable-findはTRAMP上のコマンドを発見しても、
;; file-local-nameで接続先情報を除いた絶対パスを返す。
;; lsp-modeがその絶対パスを再びexecutable-findへ渡すと、
;; ローカル側のファイルとして検査され、サーバー未検出になる。
;;
;; lsp-server-present?をTRAMPの絶対パスの場合だけ補正する。
;; executable-find/file-exists-p自体は変更しないので、
;; ローカル接続と相対コマンド名の既存動作を維持できる。
;;
;; TypeScriptには別の同種の問題がある。Node.jsのrequire.resolveは
;; コンテナ内の絶対パスを返すが、lsp-javascriptはそれをローカルの
;; f-exists?で検査する。存在確認にだけTRAMPパスを使い、Language
;; Serverへ渡す値はコンテナ内の絶対パスのままにしておく。
;;
;; Luaは共通のlsp-server-present?を使わず、専用の検査関数を使う。
;; リモートのLuaバッファに限り起動コマンド名を明示する。
;;
;; lsp-server-present?とlsp-clients-typescript-server-pathは外部パッケージ
;; の関数なので、lsp-mode更新時に回避策の要否を再確認すること。

(defvar lsp-clients-lua-language-server-command)
(defvar lsp-clients-typescript-prefer-use-project-ts-server)
(declare-function lsp-clients-typescript-require-resolve
                  "lsp-javascript" (&optional dir))


(defun my/lsp-tramp-file-name (path)
  "リモート上の絶対PATHを、Emacsが検査できるTRAMPパスにする。
ローカルのパス、コマンド名、すでにTRAMP形式のパスにはnilを返す。"
  (when-let* ((prefix (file-remote-p default-directory))
              ((stringp path))
              ((file-name-absolute-p path))
              ((not (file-remote-p path))))
    (concat prefix path)))


(defun my/lsp-server-present-with-tramp-path (original command)
  "TRAMPの絶対COMMANDだけリモート上で検査し、他はORIGINALへ委譲する。"
  (if-let* ((path (my/lsp-tramp-file-name (car command))))
      (file-executable-p path)
    (funcall original command)))


(defun my/lsp-enable-tramp-server-check ()
  "lsp-modeの共通サーバー検査をTRAMPの絶対パスに対応させる。"
  (unless (advice-member-p #'my/lsp-server-present-with-tramp-path
                           'lsp-server-present?)
    (advice-add 'lsp-server-present? :around
                #'my/lsp-server-present-with-tramp-path)))


(defun my/lsp-lua-remote-command-setup ()
  "TRAMP上のLuaにだけ、PATHから解決する起動コマンドを指定する。"
  (when (file-remote-p default-directory)
    (setq-local lsp-clients-lua-language-server-command
                '("lua-language-server" "-E"))))


(defun my/lsp-typescript-server-path-with-tramp (original)
  "TRAMP上のプロジェクト内TypeScriptを検出し、なければORIGINALへ委譲する。"
  (or (when (and (file-remote-p default-directory)
                 lsp-clients-typescript-prefer-use-project-ts-server)
        (when-let* ((path (lsp-clients-typescript-require-resolve))
                    (remote-path (my/lsp-tramp-file-name path))
                    ((file-exists-p remote-path)))
          ;; tsserverはリモートで起動するため、接続先情報を付けずに返す。
          path))
      (funcall original)))


(defun my/lsp-enable-tramp-typescript-server-path ()
  "TypeScriptのプロジェクト内パス検査をTRAMP対応にする。"
  (unless (advice-member-p #'my/lsp-typescript-server-path-with-tramp
                           'lsp-clients-typescript-server-path)
    (advice-add 'lsp-clients-typescript-server-path :around
                #'my/lsp-typescript-server-path-with-tramp)))


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



;;; jq Playground ---------------------------------------------------

(defun my/jq-playground ()
  "jqの式を試すためのJSONバッファを開く。
選択範囲があれば、その文字列でPlaygroundの内容を置き換える。
選択範囲がなければ既存の内容を維持する。
JSONを編集したらC-c C-jで \`jq-interactively' を起動する。"
  (interactive)
  (let* ((text (when (use-region-p)
                 (buffer-substring-no-properties
                  (region-beginning) (region-end))))
         (name "*jq-playground*")
         (existing (get-buffer name))
         (buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (unless existing
        (js-json-mode)
        (insert "[]\n")
        ;; 通常のJSONバッファへ影響しないよう、専用のキーマップを使う。
        (let ((map (copy-keymap (current-local-map))))
          (keymap-set map "C-c C-j" #'jq-interactively)
          (use-local-map map)))
      (when text
        (erase-buffer)
        (insert text)))
    (switch-to-buffer buffer)))

(provide 'my-development)

;;; my-development.el ends here
