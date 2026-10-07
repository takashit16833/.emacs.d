;;; my-haskell-indent.el --- Fourmolu-assisted indentation -*- lexical-binding: t; -*-

;;; Commentary:
;; TABではFourmoluの出力から対象行の開始位置だけを取り出す。
;; 空行は一時的な識別名で補い、RETでも入力途中の位置を問い合わせる。
;; 仮コード・整形結果はバッファに戻さず、先頭の空白だけを変更する。
;; ブロックの先頭を動かすTABでは、そのブロックも同じ幅だけ動かす。
;; 解析不能・実行失敗・時間切れなら局所的な規則を使う。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'treesit)

(defgroup my-haskell-indent nil
  "Fourmoluと組み合わせた入力中のインデント。"
  :group 'languages)

(defcustom my-haskell-indent-command "fourmolu"
  "Fourmoluの実行ファイル。"
  :type 'string)

(defcustom my-haskell-indent-timeout 0.15
  "1回のインデントで外部処理を待つ時間の上限（秒）。"
  :type 'number)

(defcustom my-haskell-indent-fallback-offset 2
  "Fourmoluの設定を取得できない場合のインデント幅。"
  :type 'natnum)

(defcustom my-haskell-indent-max-size 100000
  "Fourmoluへの入力の最大文字数。"
  :type 'integer)

(defvar my-haskell-indent--deadline nil)
(defvar my-haskell-indent--failure nil)
(defvar-local my-haskell-indent--offset-cache nil)
(defvar-local my-haskell-indent--saved nil)
(defvar-local my-haskell-indent-last-result nil
  "直前の計算結果。:backend、:column、:seconds、:reasonを持つ。")

(defun my-haskell-indent--file ()
  "問い合わせに使うファイル名を返す。"
  (file-local-name
   (or buffer-file-name (expand-file-name "Main.hs" default-directory))))

(defun my-haskell-indent--format (source)
  "SOURCEをFourmoluへ渡し、成功時だけ出力を返す。
外部処理の時間制限は`my-haskell-indent--deadline'で共有する。"
  (cond
   ((> (length source) my-haskell-indent-max-size)
    (setq my-haskell-indent--failure 'too-large) nil)
   ((and my-haskell-indent--deadline
         (>= (float-time) my-haskell-indent--deadline))
    (setq my-haskell-indent--failure 'timeout) nil)
   ((and (not (file-remote-p default-directory))
         (not (executable-find my-haskell-indent-command)))
    (setq my-haskell-indent--failure 'missing-executable) nil)
   (t
    (let ((output (generate-new-buffer " *haskell-indent-output*"))
          (errors (generate-new-buffer " *haskell-indent-errors*"))
          (file (my-haskell-indent--file))
          process)
      (unwind-protect
          (condition-case err
              (progn
                (setq process
                      (make-process
                       :name "haskell-indent" :buffer output :stderr errors
                       :command (list my-haskell-indent-command
                                      "--stdin-input-file" file)
                       :coding 'utf-8-unix :connection-type 'pipe
                       :noquery t :file-handler t :sentinel #'ignore))
                (when process
                  (process-send-string process source)
                  (process-send-eof process)
                  (while (and (process-live-p process)
                              (< (float-time) my-haskell-indent--deadline))
                    (accept-process-output
                     process (min 0.01 (max 0.0 (- my-haskell-indent--deadline
                                                  (float-time))))))
                  (cond
                   ((process-live-p process)
                    (setq my-haskell-indent--failure 'timeout) nil)
                   ((and (eq (process-status process) 'exit)
                         (zerop (process-exit-status process)))
                    (with-current-buffer output (buffer-string)))
                   (t (setq my-haskell-indent--failure 'parse-error) nil))))
            (file-error
             (setq my-haskell-indent--failure (error-message-string err)) nil))
        (when (and process (process-live-p process)) (delete-process process))
        (when-let* ((stderr-process (get-buffer-process errors)))
          (delete-process stderr-process))
        (kill-buffer output)
        (kill-buffer errors))))))

(defun my-haskell-indent--config-key ()
  "インデント幅の再取得が必要か判定するための情報を返す。"
  (unless (file-remote-p default-directory)
    (let* ((origin (if buffer-file-name (file-name-directory buffer-file-name)
                     default-directory))
           (directory (locate-dominating-file origin "fourmolu.yaml"))
           (file (and directory (expand-file-name "fourmolu.yaml" directory))))
      (list origin buffer-file-name my-haskell-indent-command
            my-haskell-indent-fallback-offset file
            (and file (file-attribute-modification-time (file-attributes file)))))))

(defun my-haskell-indent--offset ()
  "プロジェクトのFourmoluからインデント幅を取得する。"
  (let ((key (my-haskell-indent--config-key)))
    (if (and key (equal key (car my-haskell-indent--offset-cache)))
        (cdr my-haskell-indent--offset-cache)
      (let* ((output (my-haskell-indent--format
                      "myIndentWidth = do\n  myIndentWidthProbe\n"))
             (width (and output
                         (string-match "\n\\( +\\)myIndentWidthProbe" output)
                         (length (match-string 1 output)))))
        ;; 実行失敗をキャッシュしない。PATHや接続復旧後に再試行できる。
        (when (and key width)
          (setq my-haskell-indent--offset-cache (cons key width)))
        (or width my-haskell-indent-fallback-offset)))))

(defun my-haskell-indent--tokens (source)
  "SOURCEの終端語句を（文字列 開始位置 親の種類）として返す。
コメントや文字列の内部は語句に分割しない。位置は0から数える。"
  (when (and (treesit-available-p) (treesit-language-available-p 'haskell))
    (with-temp-buffer
      (insert source)
      (let ((root (treesit-parser-root-node (treesit-parser-create 'haskell)))
            result)
        (cl-labels
            ((walk (node parents anchors)
               (let* ((type (treesit-node-type node))
                      (count (treesit-node-child-count node))
                      (parents (cons type parents))
                      (anchor (cond
                               ((equal type "do")
                                (treesit-node-child-by-field-name node "statement"))
                               ((member type '("local_binds" "alternatives")) node)))
                      (anchors (if anchor
                                   (cons (cons (1- (treesit-node-start anchor))
                                               (treesit-node-end node)) anchors)
                                 anchors)))
                 (if (or (zerop count)
                         (member type '("comment" "haddock" "string" "char"
                                        "quasiquote" "pragma" "cpp")))
                     (when (< (treesit-node-start node) (treesit-node-end node))
                       (push (list (treesit-node-text node t)
                                   (1- (treesit-node-start node)) parents anchors)
                             result))
                   (dotimes (i count)
                     (walk (treesit-node-child node i) parents anchors))))))
          (walk root nil nil))
        (nreverse result)))))

(defun my-haskell-indent--position-column (source position)
  "SOURCEの0から数えたPOSITIONの列を返す。"
  (with-temp-buffer
    (insert source) (goto-char (1+ position)) (current-column)))

(defun my-haskell-indent--column-map (source output)
  "語句が一致する場合にSOURCEの位置とOUTPUTの列の対応表を返す。"
  (let ((before (my-haskell-indent--tokens source))
        (after (my-haskell-indent--tokens output)))
    (when (and before (equal (mapcar #'car before) (mapcar #'car after)))
      (with-temp-buffer
        (insert output)
        (cl-mapcar
         (lambda (original formatted)
           (goto-char (1+ (cadr formatted)))
           (cons (cadr original) (current-column)))
         before after)))))

(defun my-haskell-indent--mapped-column (source position output)
  "SOURCEのPOSITIONにある語句をOUTPUTと対応付けて列を返す。
語句の追加・削除・並べ替えがあれば、対応位置を推測せずnilを返す。"
  (let* ((map (my-haskell-indent--column-map source output))
         (column (cdr (assq position map)))
         (token (cl-find position (my-haskell-indent--tokens source) :key #'cadr))
         (anchor (cl-find-if (lambda (entry) (/= (car entry) position))
                            (nth 3 token))))
    (when column
      ;; 既存のレイアウト境界に合わせる。例: "do print 1" の次は
      ;; Fourmoluが改行した列ではなく、実際のprintの列に揃える必要がある。
      (when-let* ((anchor-column (and anchor (cdr (assq (car anchor) map)))))
        (setq column (+ column (- (my-haskell-indent--position-column source (car anchor))
                                  anchor-column))))
      column)))

(defun my-haskell-indent--previous ()
  "直前の空行でない行を（行頭位置 インデント 本文）として返す。"
  (save-excursion
    (beginning-of-line)
    (let (found)
      (while (and (not found) (zerop (forward-line -1)))
        (unless (looking-at-p "[ \t]*$")
          (setq found
                (list (point) (current-indentation)
                      (string-trim
                       (buffer-substring-no-properties
                        (line-beginning-position) (line-end-position)))))))
      found)))

(defun my-haskell-indent--fragment-start ()
  "現在行の属する宣言の開始位置を返す。
不完全な構文木でも、列0の宣言を境界として他の編集中の宣言を除く。"
  (save-excursion
    (beginning-of-line)
    (unless (looking-at-p "[^ \t\n-#]")
      (re-search-backward "^[^ \t\n-#]" nil 'move))
    (line-beginning-position)))

(defun my-haskell-indent--pragmas ()
  "構文補完時にも元のLANGUAGE pragmaを保持する。"
  (mapconcat #'car
             (cl-remove-if-not
              (lambda (token) (equal (car (caddr token)) "pragma"))
              (my-haskell-indent--tokens
               (buffer-substring-no-properties (point-min) (point-max))))
             "\n"))

(defun my-haskell-indent--protected-p ()
  "現在行が文字列・複数行コメント等の内部なら非nilを返す。"
  (let* ((position (save-excursion (back-to-indentation) (point)))
         (token (cl-find-if
                 (lambda (token)
                   (and (<= (cadr token) (1- position))
                        (< (1- position) (+ (cadr token) (length (car token))))))
                 (my-haskell-indent--tokens
                  (buffer-substring-no-properties (point-min) (point-max))))))
    (and token
         (member (car (caddr token))
                 '("string" "char" "quasiquote" "comment" "haddock" "cpp" "pragma"))
         ;; コメントの開始行自体も、意図的な配置を維持する。
         t)))

(defun my-haskell-indent--fallback (width previous)
  "WIDTHとPREVIOUSから外部処理なしの列を計算する。"
  (let ((text (or (nth 2 previous) ""))
        (indent (or (cadr previous) 0)))
    (cond
     ((null previous) 0)
     ((string-match-p "\\`--" text) indent)
     ((string-match-p "\\`module\\_>.*\\_<where\\'" text) 0)
     ((string-match-p "[([{]\\s-*\\'" text) (+ indent width))
     ((string-match-p "\\\\case\\s-*\\'" text) (+ indent width))
     ((string-match-p "\\(?:\\_<\\(?:do\\|mdo\\|of\\|where\\|let\\|then\\|else\\)\\|=\\|->\\|<-\\|::\\|=>\\)\\s-*\\'" text)
      (+ indent width))
     (t indent))))

(defun my-haskell-indent--pending (tokens)
  "TOKENSから未完のlet、ifと括弧を取得する。"
  (let (lets ifs delimiters)
    (dolist (token tokens)
      (pcase (car token)
        ("let" (unless (member "let" (cdr (caddr token))) (push token lets)))
        ("in" (pop lets))
        ("if" (push token ifs))
        ("else" (pop ifs))
        ((or "(" "[" "{") (push (car token) delimiters))
        ((or ")" "]" "}") (pop delimiters))))
    (list lets ifs delimiters)))

(defun my-haskell-indent--probe (width previous)
  "空行を補完した（ソース 識別名）を返す。"
  (let* ((start (my-haskell-indent--fragment-start))
         (prefix (buffer-substring-no-properties start (line-beginning-position)))
         (tokens (my-haskell-indent--tokens prefix))
         (last (car (last tokens)))
         (word (car last))
         (parents (caddr last))
         (pending (my-haskell-indent--pending tokens))
         (column (my-haskell-indent--fallback width previous))
         (name "myHaskellIndentProbe")
         (binding (or (member word '("let" "where" "{"))
                      (and (member "local_binds" parents)
                           (not (member word '("=" "->" "<-" "do" "of"))))))
         (alternative (or (equal word "of")
                          (and (equal word "case") (member "lambda_case" parents))
                          (and (member "alternatives" parents)
                               (not (member word '("->" "do" "=" "then" "else")))))))
    (while (save-excursion
             (goto-char (point-min)) (search-forward name nil t))
      (setq name (concat name "X")))
    (when (and binding (member "local_binds" parents))
      (when-let* ((first (cl-find-if
                         (lambda (token) (member "local_binds" (caddr token)))
                         tokens)))
        (setq column (with-temp-buffer
                       (insert prefix) (goto-char (1+ (cadr first)))
                       (current-column)))))
    (when (nth 2 pending)
      (setq column (max width column))
      (setq binding (equal (car (nth 2 pending)) "{")))
    ;; 空行の意味は一意ではない。通常は現在のブロックの続きと解釈する。
    (when (and (zerop column) (not (member word '("=" "->" "::" "=>" "[" "("))))
      (setq binding t))
    (let ((source
           (concat (my-haskell-indent--pragmas) "\n" prefix
                   (make-string column ?\s) name
                   (cond (alternative " -> undefined")
                         (binding " = undefined")
                         (t ""))
                   "\n")))
      (dolist (token (car pending))
        (let ((indent (with-temp-buffer
                        (insert prefix) (goto-char (1+ (cadr token)))
                        (current-indentation))))
          (setq source (concat source (make-string indent ?\s) "in undefined\n"))))
      (dolist (token (cadr pending))
        (let ((indent (with-temp-buffer
                        (insert prefix) (goto-char (1+ (cadr token)))
                        (current-indentation))))
          (setq source (concat source (make-string indent ?\s) "else undefined\n"))))
      (when (nth 2 pending)
        (setq source (concat source (make-string (max 1 column) ?\s))))
      (dolist (delimiter (nth 2 pending))
        (setq source (concat source (pcase delimiter ("(" ")") ("[" "]") ("{" "}")))))
      (list source name))))

(defun my-haskell-indent--existing-column (source)
  "現在行をSOURCEまたは単独の宣言として整形し、列を返す。"
  (or (when-let* ((output (my-haskell-indent--format source)))
        (my-haskell-indent--mapped-column source (1- (point)) output))
      ;; 他の宣言が入力途中でも、対象の宣言だけなら解析できる場合がある。
      (let* ((start (my-haskell-indent--fragment-start))
             (end (save-excursion
                    (forward-line 1)
                    (if (re-search-forward "^[^ \t\n-#]" nil t)
                        (match-beginning 0) (point-max))))
             (header (concat (my-haskell-indent--pragmas) "\n"))
             (fragment (concat header
                               (buffer-substring-no-properties start end))))
        (unless (equal fragment source)
          (when-let* ((output (my-haskell-indent--format fragment)))
            (my-haskell-indent--mapped-column
             fragment (+ (length header) (- (point) start)) output))))))

(defun my-haskell-indent--probe-column (probe)
  "PROBEを整形して識別名の列を返す。"
  (when-let* ((output (my-haskell-indent--format (car probe))))
    (let ((source (car probe)))
      (when (string-match (concat "\\_<" (regexp-quote (cadr probe)) "\\_>") source)
        (my-haskell-indent--mapped-column source (match-beginning 0) output)))))

(defun my-haskell-indent-column ()
  "現在行のインデント列を計算する。バッファは変更しない。"
  (save-excursion
    (save-restriction
      (widen)
      (back-to-indentation)
      (let* ((started (float-time))
             (my-haskell-indent--deadline (+ started my-haskell-indent-timeout))
             (my-haskell-indent--failure nil)
             (previous (my-haskell-indent--previous))
             (blank (eolp))
             (keep (or (my-haskell-indent--protected-p)
                       (and blank (string-prefix-p "--" (or (nth 2 previous) "")))))
             (width (if keep my-haskell-indent-fallback-offset
                      (my-haskell-indent--offset)))
             (source (buffer-substring-no-properties (point-min) (point-max)))
             (column
              (unless keep
                (if blank
                    (my-haskell-indent--probe-column
                     (my-haskell-indent--probe width previous))
                  (my-haskell-indent--existing-column source))))
             (backend (cond (keep 'preserve) (column 'fourmolu) (t 'fallback))))
        (unless column
          (setq column (if keep
                           (if blank (or (cadr previous) 0) (current-indentation))
                         (my-haskell-indent--fallback width previous))))
        (setq my-haskell-indent-last-result
              (list :backend backend :column column
                    :seconds (- (float-time) started)
                    :reason (and (eq backend 'fallback)
                                 (or my-haskell-indent--failure 'unmapped))))
        column))))

(defun my-haskell-indent-line ()
  "現在行をインデントする。本文とブロック内の相対位置を保つ。"
  (interactive)
  (let* ((in-text (> (current-column) (current-indentation)))
         (position (copy-marker (point)))
         (column (my-haskell-indent-column))
         (token (save-excursion
                  (save-restriction
                    (widen) (back-to-indentation)
                    (cl-find (1- (point))
                             (my-haskell-indent--tokens
                              (buffer-substring-no-properties (point-min) (point-max)))
                             :key #'cadr))))
         (block (and (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu)
                     (cl-find (cadr token) (nth 3 token) :key #'car))))
    (unwind-protect
        (progn
          (if (and block (/= column (current-indentation)))
              (atomic-change-group
                (indent-rigidly (line-beginning-position) (cdr block)
                                (- column (current-indentation))))
            (indent-line-to column))
          (if in-text (goto-char position) (back-to-indentation)))
      (set-marker position nil))))

(defun my-haskell-indent-newline (&optional count)
  "前の行を変更せず、COUNT行改行して新しい行だけをインデントする。"
  (interactive "*p")
  (let ((electric-indent-mode nil))
    (newline (or count 1)))
  (my-haskell-indent-line))

(defun my-haskell-indent-region (begin end)
  "BEGINからENDの範囲を、構文を保てる場合だけインデントする。
Fourmoluの語句列が同じ場合に全行の列を計算し、計算後にまとめて適用する。"
  (interactive "r")
  (let* ((my-haskell-indent--deadline (+ (float-time) my-haskell-indent-timeout))
         (source (buffer-substring-no-properties (point-min) (point-max)))
         (output (my-haskell-indent--format source))
         (map (and output (my-haskell-indent--column-map source output)))
         changes)
    (unless output (user-error "Fourmoluで解析できないため範囲のインデントを変更できません"))
    (save-excursion
      (goto-char begin)
      (beginning-of-line)
      (while (< (point) end)
        (back-to-indentation)
        (unless (or (eolp) (my-haskell-indent--protected-p))
          (let ((column (cdr (assq (1- (point)) map))))
            (unless column
              (user-error "整形で語句が変わるため、保存時の整形を使用してください"))
            (push (cons (line-beginning-position) column) changes)))
        (forward-line 1))
      (atomic-change-group
        ;; 下から適用すれば、先行行の文字位置がずれない。
        (dolist (change changes)
          (goto-char (car change)) (indent-line-to (cdr change)))))))

(defun my-haskell-indent-report ()
  "最後に使った処理・列・所要時間を表示する。"
  (interactive)
  (message "%S" my-haskell-indent-last-result))

(defvar-keymap my-haskell-indent-mode-map
  "RET" #'my-haskell-indent-newline
  "<return>" #'my-haskell-indent-newline
  "C-j" #'my-haskell-indent-newline)

;;;###autoload
(define-minor-mode my-haskell-indent-mode
  "Fourmoluを使ってTAB/RETのインデント位置を決める。"
  :lighter nil
  :keymap my-haskell-indent-mode-map
  (if my-haskell-indent-mode
      (unless my-haskell-indent--saved
        (setq my-haskell-indent--saved
              (mapcar (lambda (variable)
                        (list variable (local-variable-p variable) (symbol-value variable)))
                      '(indent-line-function indent-region-function electric-indent-inhibit)))
        (setq-local indent-line-function #'my-haskell-indent-line)
        (setq-local indent-region-function #'my-haskell-indent-region)
        ;; electric-indentが改行前の行を再インデントすることを防ぐ。
        (setq-local electric-indent-inhibit t))
    (dolist (entry my-haskell-indent--saved)
      (if (cadr entry)
          (set (make-local-variable (car entry)) (caddr entry))
        (kill-local-variable (car entry))))
    (setq my-haskell-indent--saved nil)))

(provide 'my-haskell-indent)
;;; my-haskell-indent.el ends here
