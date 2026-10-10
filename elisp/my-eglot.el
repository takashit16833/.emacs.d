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

(provide 'my-eglot)

;;; my-eglot.el ends here
