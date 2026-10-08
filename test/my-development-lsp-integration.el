;;; my-development-lsp-integration.el --- Real lsp-mode resolve tests -*- lexical-binding: t; -*-

;;; Commentary:
;; lsp-modeのJSON復号・補完処理・JSON符号化を実際に通す結合テスト。
;; HLSサーバーへの通信だけを差し替えるため、HLS本体は不要。
;;
;; リポジトリ直下で実行:
;; emacs -Q --batch -L elisp --eval '(package-initialize)' \
;;   -l test/my-development-lsp-integration.el \
;;   --eval '(ert-run-tests-batch-and-exit "my/lsp-integration-")'
;;
;; 通常の -Q 単体テストとは異なり、インストール済みのlsp-modeが必要。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'lsp-completion)
(require 'my-development)


;; 問題が再現した際のcompletionItem/resolveの補完候補。
;; falseはlsp-modeの受信処理でnilになるため、送信時にnullへ変わる。
(defconst my-test/hls-resolve-json
  (concat
   "{\"label\":\"embedText\",\"insertText\":\"embedText\","
   "\"data\":{\"resolvePlugin\":\"ghcide-completions\","
   "\"resolveURI\":\"file:///workspace/app/Main.hs\","
   "\"resolveValue\":{\"itemFile\":\"file:///workspace/app/Main.hs\","
   "\"itemName\":[\"Main\",\"rag-lab-0.1.0.0-inplace-rag-lab\","
   "\"v\",\"embedText\"],\"itemNeedsType\":false}}}"))


(defun my-test/lsp-resolve-request-json (json)
  "JSONから候補を読み込み、実際の補完処理で送信する内容を返す。"
  (let ((item (lsp--read-json json))
        (was-advised
         (advice-member-p #'my/lsp-completion-fix-haskell-resolve-data
                          'lsp-completion--fix-resolve-data))
        sent-method
        sent-json)
    ;; 起動設定と同じadviceを取り付ける。実際のlsp-modeの関数は模擬しない。
    (unless was-advised
      (advice-add 'lsp-completion--fix-resolve-data :after
                  #'my/lsp-completion-fix-haskell-resolve-data))
    (unwind-protect
        (cl-letf (((symbol-function 'lsp-feature?)
                   (lambda (_method) t))
                  ((symbol-function 'lsp-request)
                   (lambda (method params &rest _args)
                     (setq sent-method method
                           sent-json (lsp--json-serialize params)))))
          (lsp-completion--resolve item))
      (unless was-advised
        (advice-remove 'lsp-completion--fix-resolve-data
                       #'my/lsp-completion-fix-haskell-resolve-data)))
    (should (equal sent-method "completionItem/resolve"))
    (should sent-json)
    ;; 送信JSONを再び読み、nullとfalseを区別して検証する。
    (json-parse-string sent-json
                       :object-type 'hash-table
                       :null-object :json-null
                       :false-object :json-false)))


(defun my-test/lsp-resolve-needs-type (item)
  "ITEMのresolveValue内のitemNeedsTypeを取り出す。"
  (gethash "itemNeedsType"
           (gethash "resolveValue"
                    (gethash "data" item))))


(ert-deftest my/lsp-integration-hls-resolve-false-is-sent-as-false ()
  "HLSのfalseが、実際のresolve経路でnullにならないこと。"
  (let* ((input (lsp--read-json my-test/hls-resolve-json))
         (value (lsp-get (lsp:completion-item-data? input) :resolveValue))
         (sent (my-test/lsp-resolve-request-json my-test/hls-resolve-json)))
    ;; 読み込み時点ではfalseがnilに変わっている。
    (should (lsp-member? value :itemNeedsType))
    (should-not (lsp-get value :itemNeedsType))
    ;; それでも送信時はJSON falseに復元される。
    (should (eq :json-false (my-test/lsp-resolve-needs-type sent)))
    (should (equal "embedText" (gethash "label" sent)))
    (should (equal "ghcide-completions"
                   (gethash "resolvePlugin" (gethash "data" sent))))))


(ert-deftest my/lsp-integration-hls-resolve-true-is-unchanged ()
  "HLSのtrueをfalseへ変更しないこと。"
  (let* ((json (replace-regexp-in-string
                "\"itemNeedsType\":false" "\"itemNeedsType\":true"
                my-test/hls-resolve-json t t))
         (sent (my-test/lsp-resolve-request-json json)))
    (should (eq t (my-test/lsp-resolve-needs-type sent)))))


(ert-deftest my/lsp-integration-hls-resolve-only-ghcide-is-changed ()
  "他プラグインの補完データは変換しないこと。"
  (let* ((json (replace-regexp-in-string
                "ghcide-completions" "other-plugin"
                my-test/hls-resolve-json t t))
         (sent (my-test/lsp-resolve-request-json json)))
    ;; 今回の修正はghcideのデータ構造にだけ適用する。
    (should (eq :json-null (my-test/lsp-resolve-needs-type sent)))))


;;; my-development-lsp-integration.el ends here
