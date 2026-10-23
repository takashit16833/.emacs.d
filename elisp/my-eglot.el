;;; my-eglot.el --- Eglotの補完・コードアクション調整 -*- lexical-binding: t; -*-

;;; Commentary:
;; 【現象と再現条件】
;; HaskellでData.Aesonをimportしていない状態で「enc」から「encode」を
;; 補完すると、Eglot 31.1ではencodeだけが挿入され、
;; 必要な「import Data.Aeson (encode)」が追加されなかった。
;; 同じHLSでもlsp-modeではimport文まで自動挿入された。
;; これは補完「候補が出ない」問題ではなく、候補「確定後」の処理の違い。
;; haskell.maxCompletionsを増やしても解決しない。
;;
;; 【原因：Emacs 31.1とHLSのソースで確認】
;; HLSは未importの候補にCompletionItem.commandを付け、
;; ghcide-extend-import-actionのextendImportコマンドを実行させる。
;; HLS側でimport文を編集し、workspace/applyEditを送る仕組み。
;; 一方、Eglot 31.1のeglot-completion-at-pointのexit-functionは
;; 文字挿入・additionalTextEdits・didChangeまで処理するが、
;; CompletionItem.commandを実行しない。
;;
;; 根拠となる実装:
;; Emacs 31.1:
;; https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/progmodes/eglot.el
;;   eglot-completion-at-pointの:exit-function、eglot-execute
;; HLS:
;; https://github.com/haskell/haskell-language-server/blob/master/ghcide/src/Development/IDE/Plugin/Completions/Logic.hs
;;   mkCompl、mkAdditionalEditsCommand
;; https://github.com/haskell/haskell-language-server/blob/master/plugins/hls-refactor-plugin/src/Development/IDE/Plugin/CodeAction.hs
;;   extendImportHandler
;;
;; 【採用した対応と理由】
;; Eglot本体の補完処理は置き換えず、Haskellでのみ補完確定処理を包む。
;; 元のexit-functionが正常終了した後で、受信したcommandを
;; Eglot標準のeglot-executeで実行する。
;; Eglotによるスニペット展開や追加編集・変更通知の順序を維持できる。
;; commandはHLS側の機能なので、クライアント側でimport文を自作しない。
;; 他の言語へ不要な影響を広げず、Eglot内部への介入を最小限にする。
;;
;; 【依存・検証・削除条件】
;; 候補から元のCompletionItemを得るため、Eglot内部の文字列プロパティ
;; eglot--lsp-itemに依存する。Eglot更新時はこの形式も確認する。
;; test/my-eglot-test.elは実行順序、キャンセル、他言語への非干渉、
;; 失敗時の非実行などをモックで確認するが、HLSとの通信は検証しない。
;; 実際のHLSで「enc → encode + import追加」も再確認すること。
;; 将来Eglot本体がCompletionItem.commandに対応した場合は、
;; 二重実行を避けるためこのadviceを削除して再テストする。

;;; Code:

(require 'cl-lib)

;;; TRAMPでのdiff-hl

(declare-function eglot-managed-p "eglot" ())
(declare-function diff-hl-mode "diff-hl" (&optional arg))

(defun my/eglot-enable-remote-diff-hl ()
  "Eglot接続後、TRAMPのファイルでdiff-hlを有効にする。"
  (when (and (eglot-managed-p)
             buffer-file-name
             (file-remote-p buffer-file-name))
    (require 'diff-hl)
    (diff-hl-mode 1)))

;; Eglot 31.1は現在位置に提示した候補が1件だけの場合、
;; eglot-code-actionsの対話的実行でも選択を省いて即時実行する。
;; このコマンドでは、呼び出し中だけその提案を無視して、
;; Eglot本来のcompleting-readによる候補選択に進ませる。
;; 内部変数への依存はここだけに限定し、Eglot更新時に再確認する。
(defvar eglot--suggestion-overlay)
(declare-function eglot-code-actions "eglot"
                  (beg &optional end action-kind interactive))

(defun my/eglot-code-actions ()
  "コードアクションを1件だけの場合も必ず候補から選択する。"
  (interactive)
  (let ((eglot--suggestion-overlay nil))
    (call-interactively #'eglot-code-actions)))

(declare-function eglot-current-server "eglot" ())
(declare-function eglot-execute "eglot" (server action))
(declare-function eglot-server-capable-or-lose "eglot" (&rest features))
(declare-function eglot--current-server-or-lose "eglot" ())
(declare-function eglot--pos-to-lsp-position "eglot" (&optional position))
(declare-function eglot-region-range "eglot" (from to))
(declare-function eglot--request "eglot" (server method params &rest options))
(declare-function eglot--TextDocumentIdentifier "eglot" ())
(declare-function eglot--apply-text-edits "eglot"
                  (edits &optional version silent))
(declare-function eglot--lsp-position-to-point "eglot" (position))

(defun my/eglot-haskell-completion-command (capf)
  "Haskellの補完確定後にHLSの追加コマンドを実行する。
eglot-completion-at-pointの戻り値（CAPF）を包む:filter-return advice。"
  (when (and (consp capf) (derived-mode-p 'haskell-ts-mode))
    (when-let* ((exit (plist-get (nthcdr 3 capf) :exit-function))
                (server (eglot-current-server)))
      (plist-put (nthcdr 3 capf) :exit-function
            (lambda (candidate status)
              (let* ((item (when (and (stringp candidate)
                                      (> (length candidate) 0))
                             (get-text-property 0 'eglot--lsp-item candidate)))
                     (command (and (memq status '(finished exact))
                                   (plist-get item :command))))
                ;; 元の確定処理に挿入・スニペット・resolve・didChangeを任せる。
                ;; 先にcommandを実行すると編集順序が崩れるため、必ず後で実行する。
                (funcall exit candidate status)
                (when command
                  ;; eglot-executeはCommandの:titleを破壊的に取り除く。
                  ;; 候補が保持する元データを変更しないためコピーを渡す。
                  (eglot-execute server (copy-tree command))))))))
  capf)

;; 【修飾名の補完が消える問題（自動importとは別問題）】
;; ローカルのHaskellで「import qualified Data.Text as T」のもと、
;; 「T.unp」からunpackを補完できなかった。Corfuを介さず
;; eglot-completion-at-pointのtableを検査した結果、unpackは
;; 28件の候補中に存在するのに、CAPFのprefixが「T.unp」となり、
;; そのprefixでall-completionsすると候補が消えることを確認した。
;; HLSからの候補不足やTRAMPではなく、Eglotのboundsと候補名の不一致。
;;
;; Eglot 31.1のeglot-completion-at-pointは
;; bounds-of-thing-at-point 'symbolで補完範囲を決めるため、
;; Haskellの修飾名を一つのsymbolと判定した場合に問題になる。
;; https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/progmodes/eglot.el
;;
;; 【対応と限界】
;; Haskellのモジュール修飾名（T.unp、Data.Text.unp等）だけ、
;; Eglotがboundsを得る瞬間に末尾の「.」以降を補完範囲にする。
;; HLSの問い合わせ・候補表・補完確定処理は変更しない。
;; EglotのCAPFだけを修正し、Corfuやdabbrevの候補統合には介入しない。
;; この処理はHaskellの通常の名前・他言語へ影響させない。
;; 演算子補完等は今回の対象外。Eglotやhaskell-ts-modeの更新時に
;; boundsが正しくなったなら、このadviceの必要性を再検証する。

(defun my/eglot-haskell-qualified-bounds (bounds)
  "Haskellの修飾名に限り、BOUNDSを最後のドット以降へ調整する。"
  (if (and (consp bounds)
           (<= (car bounds) (point))
           (<= (point) (cdr bounds)))
      (let ((dot (save-excursion
                   (goto-char (point))
                   (search-backward "." (car bounds) t)))
            ;; case-fold-searchがtでも[:upper:]を小文字に一致させない。
            (case-fold-search nil))
        (if (and dot
                 ;; モジュール名・別名は大文字から始まる。
                 ;; 数値や演算子を修飾名と誤認識しない。
                 (string-match-p
                  "^[[:upper:]][[:alnum:]_'.]*$"
                  (buffer-substring-no-properties (car bounds) dot))
                 (string-match-p
                  "^[[:alnum:]_']*$"
                  (buffer-substring-no-properties (1+ dot) (point))))
            (cons (1+ dot) (cdr bounds))
          bounds))
    bounds))

(defun my/eglot-haskell-qualified-completion (original &rest args)
  "Haskellの修飾名に対してだけEglotの補完開始位置を調整する。"
  (if (derived-mode-p 'haskell-ts-mode)
      (let ((bounds-function (symbol-function 'bounds-of-thing-at-point)))
        ;; EglotがCAPFを構成する間だけboundsを補正する。
        ;; グローバルな構文テーブルや他の補完コマンドは変更しない。
        (cl-letf (((symbol-function 'bounds-of-thing-at-point)
                   (lambda (thing)
                     (let ((bounds (funcall bounds-function thing)))
                       (if (eq thing 'symbol)
                           (my/eglot-haskell-qualified-bounds bounds)
                         bounds)))))
          (apply original args)))
    (apply original args)))


;;; インレイヒントの確定

;; LSPのtextEditsをEglotの編集処理へ渡す。表示と違い、Eglot 31.1には
;; ヒントを選んで確定するコマンドがないため、この部分だけ補う。
;; https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/progmodes/eglot.el
;; 文字列内のカーソルでは、symbolの範囲ではなく引用符を含む文字列の範囲を
;; 使う。LSPの引数名ヒントは文字列の開始位置に付くため。
;; basedpyright 1.40.2は型・引数名ヒントのtextEditsを返し、
;; 必要なimportの編集情報も含める。
;; https://github.com/DetachHead/basedpyright/blob/v1.40.2/packages/pyright-internal/src/languageService/inlayHintsProvider.ts

(defun my/eglot--inlay-hint-target-bounds ()
  "カーソル位置の式の範囲を返す。文字列では引用符を含める。"
  (let* ((state (syntax-ppss))
         (string-start (and (nth 3 state) (nth 8 state)))
         (string-end (and string-start
                          (ignore-errors (scan-sexps string-start 1)))))
    (or (and string-end (cons string-start string-end))
        (bounds-of-thing-at-point 'sexp)
        (bounds-of-thing-at-point 'symbol))))

(defun my/eglot--same-lsp-position-p (a b)
  "AとBが同じLSP上の位置を表す場合は非nilを返す。"
  (and a b
       (eql (plist-get a :line) (plist-get b :line))
       (eql (plist-get a :character) (plist-get b :character))))

(defun my/eglot--inlay-hints-at-bounds (hints start end)
  "範囲STARTからENDに付くHINTSを返す。
型ヒントは末尾、引数名ヒントは先頭を優先する。
kindが省略された場合はどちらの位置でも候補に含める。"
  (cl-remove-if-not
   (lambda (hint)
     (let ((position (plist-get hint :position)))
       (pcase (plist-get hint :kind)
         (1 (my/eglot--same-lsp-position-p position end))
         (2 (my/eglot--same-lsp-position-p position start))
         (_ (or (my/eglot--same-lsp-position-p position start)
                (my/eglot--same-lsp-position-p position end))))))
   (append hints nil)))

(defun my/eglot--inlay-hint-label (hint)
  "HINTのラベルを補完候補に表示できる文字列へ変換する。"
  (let ((label (plist-get hint :label)))
    (cond
     ((stringp label) label)
     ((vectorp label)
      (mapconcat (lambda (part) (or (plist-get part :value) ""))
                 label ""))
     (t (format "%s" label)))))

(defun my/eglot--choose-inlay-hint (hints)
  "HINTSが1件なら即座に返し、複数ならcompleting-readで選択する。"
  (if (null (cdr hints))
      (car hints)
    (let* ((choices (cl-loop for hint in hints
                             for index from 1
                             collect (cons (format "%d: %s" index
                                                   (my/eglot--inlay-hint-label hint))
                                           hint)))
           (selection (completing-read "Apply inlay hint: " choices nil t)))
      (cdr (assoc selection choices)))))

(defun my/eglot--matching-inlay-hint-overlays (hint)
  "HINTに対応するEglotの表示用overlayを返す。
位置・種類・表示文字列を照合し、別のヒントを巻き込まない。
複数部分からなるラベルは、全ての部分が見つかったときだけ返す。"
  (when-let* ((position (plist-get hint :position))
              (anchor (save-excursion
                        (eglot--lsp-position-to-point position)))
              (label (plist-get hint :label))
              (parts (if (vectorp label)
                         (mapcar (lambda (part) (plist-get part :value))
                                 (append label nil))
                       (list label))))
    (let* ((type-p (eql (plist-get hint :kind) 1))
           (property (if type-p 'before-string 'after-string))
           (candidates
            (cl-remove-if-not
             (lambda (ov)
               (and (overlay-get ov 'eglot--inlay-hint)
                    (if type-p
                        (= (overlay-start ov) anchor)
                      (= (overlay-end ov) anchor))
                    (overlay-get ov property)))
             (overlays-in (max (point-min) (1- anchor))
                          (min (point-max) (1+ anchor)))))
           (found nil))
      (catch 'missing
        (dolist (part parts)
          (unless (stringp part)
            (throw 'missing nil))
          (let ((ov (cl-find-if
                     (lambda (item)
                       ;; Eglotは必要に応じて左右に空白を1つ加える。
                       (let ((text (substring-no-properties
                                    (overlay-get item property))))
                         (member text
                                 (list part (concat " " part)
                                       (concat part " ")
                                       (concat " " part " ")))))
                     candidates)))
            (unless ov
              (throw 'missing nil))
            (push ov found)
            (setq candidates (delq ov candidates))))
        (nreverse found)))))

(defun my/eglot-apply-inlay-hint ()
  "カーソル位置のインレイヒントの編集情報をコードへ反映する。
編集できる候補が1件なら直接適用し、複数なら候補から選ぶ。
編集情報がないヒントは適用できない。"
  (interactive)
  (let ((bounds (my/eglot--inlay-hint-target-bounds)))
    (unless bounds
      (user-error "No expression at point"))
    (eglot-server-capable-or-lose :inlayHintProvider)
    (let* ((server (eglot--current-server-or-lose))
           ;; eglot--pos-to-lsp-positionはpointを動かす。
           (start (save-excursion
                    (eglot--pos-to-lsp-position (car bounds))))
           (end (save-excursion
                  (eglot--pos-to-lsp-position (cdr bounds))))
           (range (save-excursion
                    (eglot-region-range (line-beginning-position)
                                        (line-end-position))))
           (tick (buffer-chars-modified-tick))
           (hints (eglot--request
                   server :textDocument/inlayHint
                   (list :textDocument (eglot--TextDocumentIdentifier)
                         :range range)))
           (matches (my/eglot--inlay-hints-at-bounds hints start end))
           (editable (cl-remove-if-not
                      (lambda (hint)
                        (let ((edits (plist-get hint :textEdits)))
                          (and edits (> (length edits) 0))))
                      matches)))
      (unless (= tick (buffer-chars-modified-tick))
        (user-error "Buffer changed while requesting inlay hints"))
      (unless matches
        (user-error "No inlay hint for expression at point"))
      (unless editable
        (user-error "Inlay hint has no text edits"))
      (let ((chosen (my/eglot--choose-inlay-hint editable)))
        ;; 候補選択中の変更によって古くなった編集も適用しない。
        (unless (= tick (buffer-chars-modified-tick))
          (user-error "Buffer changed while selecting inlay hint"))
        ;; 編集前の位置で古い表示を特定し、編集成功後にのみ削除する。
        ;; 編集によってoverlayの位置が移動するため、先に控えておく。
        (let ((overlays (my/eglot--matching-inlay-hint-overlays chosen)))
          (save-excursion
            (eglot--apply-text-edits (plist-get chosen :textEdits)))
          (mapc #'delete-overlay overlays))
        (message "Applied inlay hint: %s"
                 (my/eglot--inlay-hint-label chosen))))))

(provide 'my-eglot)

;;; my-eglot.el ends here
