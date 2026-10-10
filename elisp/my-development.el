;;; my-development.el --- Development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 開発時に使用する独自コマンドを定義する。

;;; Code:


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
