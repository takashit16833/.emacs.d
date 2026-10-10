;;; my-eglot.el --- Haskellの自動import補完対応 -*- lexical-binding: t; -*-

;;; Commentary:
;;
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

(declare-function eglot-current-server "eglot" ())
(declare-function eglot-execute "eglot" (server action))

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

;; 【Haskellの色分けをTree-sitterに統一する】
;; Emacs 31.1のEglotは接続後にSemantic Tokensを有効化する。
;; HLSのトークンが届くと、最初のTree-sitterによる色分けに別のfaceが
;; 加わり、関数などの色が後から白っぽく変わる現象を確認した。
;; eglot-semantic-tokens-mode -1で元の配色に戻ることを実機で確認済み。
;; Eglot 31.1ではsemantic tokens有効化の後に
;; eglot-managed-mode-hookを呼ぶので、このhookでHaskellのみ無効化する。
;; 他言語のSemantic TokensやHaskellの補完・診断には触れない。
;; 根拠: https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/progmodes/eglot.el
;;       eglot--maybe-activate-editing-mode

(declare-function eglot-managed-p "eglot" ())
(declare-function eglot-semantic-tokens-mode "eglot" (&optional arg))

(defun my/eglot-haskell-disable-semantic-tokens ()
  "Eglot管理中のHaskellではTree-sitterの色分けを優先する。"
  (when (and (derived-mode-p 'haskell-ts-mode)
             (eglot-managed-p)
             (bound-and-true-p eglot-semantic-tokens-mode))
    (eglot-semantic-tokens-mode -1)))

(provide 'my-eglot)

;;; my-eglot.el ends here
