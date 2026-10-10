;;; my-eglot-test.el --- HLSの自動import補完対応のERT -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; my-eglot.elで補っているのは「補完候補の確定後にHLSのcommandを実行する」
;; という一点。関数名の挿入やimport文の生成はここでは実装していない。
;;
;; 退行防止の対象:
;; - 元のEglotのexit-functionを先に実行し、後からcommandを実行する
;; - finished/exact以外では実行しない
;; - Eglot由来のcommandがない候補、Haskell以外のモードには影響しない
;; - 元の確定処理に失敗した場合はcommandを実行しない
;; - eglot-executeが:titleを変更しても、受信した候補を壊さない
;;
;; HLS・Eglotの通信はモックしており、import文が実際に挿入されるかは未検証。
;; 実機ではData.Aeson未importの状態でencからencodeを確定し、
;; import Data.Aeson (encode)が追加されることを別途確認する。
;; 原因と削除条件はelisp/my-eglot.elのCommentaryを参照する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-eglot)

(ert-deftest my/eglot-haskell-completion-executes-import-after-original-exit ()
  "候補確定時はEglot本来の編集の後にHLSコマンドを実行する。"
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let* ((command '(:title "extend import"
                     :command "hls:ghcide-extend-import-action:extendImport"
                     :arguments [(:newThing "encode")]))
           (item (list :label "encode" :command command))
           (candidate (propertize "encode" 'eglot--lsp-item item))
           (events nil)
           (capf (list 1 4 nil :exit-function
                       (lambda (_candidate _status)
                         (push 'original events)))))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (server action)
                   (should (eq server 'test-hls))
                   (should (equal (plist-get action :command)
                                  (plist-get command :command)))
                   (push 'command events)
                   ;; eglot-executeと同様に:titleを破壊的に変更しても安全か確認する。
                   (cl-remf action :title))))
        (should (eq capf (my/eglot-haskell-completion-command capf)))
        (funcall (plist-get (nthcdr 3 capf) :exit-function)
                 candidate 'finished)
        (should (equal (nreverse events) '(original command)))
        (should (equal (plist-get command :title) "extend import"))))))

(ert-deftest my/eglot-haskell-completion-supports-exact-status ()
  "exactステータスでも追加コマンドを実行する。"
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let ((count 0)
          (candidate (propertize "encode" 'eglot--lsp-item
                                 '(:command (:title "extend import"
                                             :command "extendImport"))))
          (capf (list 1 4 nil :exit-function #'ignore)))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (_server _action) (cl-incf count))))
        (my/eglot-haskell-completion-command capf)
        (funcall (plist-get (nthcdr 3 capf) :exit-function) candidate 'exact)
        (should (= count 1))))))

(ert-deftest my/eglot-haskell-completion-ignores-cancel-and-unmarked-candidates ()
  "キャンセルや追加コマンドのない候補ではサーバーを呼ばない。"
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let* ((count 0)
           (candidate (propertize "encode" 'eglot--lsp-item
                                  '(:command (:title "extend import"
                                              :command "extendImport"))))
           (capf (list 1 4 nil :exit-function
                       (lambda (_candidate _status) (cl-incf count)))))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (&rest _) (ert-fail "Unexpected server command"))))
        (my/eglot-haskell-completion-command capf)
        (let ((exit (plist-get (nthcdr 3 capf) :exit-function)))
          (funcall exit candidate 'cancelled)
          (funcall exit "encode" 'finished)
          (funcall exit (propertize "encode" 'eglot--lsp-item
                                   '(:label "encode")) 'finished))
        (should (= count 3))))))

(ert-deftest my/eglot-haskell-completion-leaves-other-modes-unchanged ()
  "Haskell以外ではEglotの確定処理を変更しない。"
  (with-temp-buffer
    (let* ((original #'ignore)
           (capf (list 1 4 nil :exit-function original)))
      (setq-local major-mode 'python-ts-mode)
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () (ert-fail "Should not inspect Eglot server"))))
        (should (eq capf (my/eglot-haskell-completion-command capf)))
        (should (eq original
                    (plist-get (nthcdr 3 capf) :exit-function)))))))

(ert-deftest my/eglot-haskell-completion-does-not-execute-after-exit-error ()
  "元の確定処理が失敗した場合は追加コマンドを実行しない。"
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (let* ((candidate (propertize "encode" 'eglot--lsp-item
                                  '(:command (:title "extend import"
                                              :command "extendImport"))))
           (capf (list 1 4 nil :exit-function
                       (lambda (&rest _) (error "Original exit failed")))))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (&rest _) (ert-fail "Should not execute"))))
        (my/eglot-haskell-completion-command capf)
        (should-error (funcall (plist-get (nthcdr 3 capf) :exit-function)
                               candidate 'finished))))))

;;; Haskell修飾名の補完範囲 -----------------------------------------
;;
;; ローカルの実測ではT.unpの候補表にunpackがあったが、
;; EglotのCAPF範囲がT.unpだったため照合に失敗した。
;; ここでは範囲補正と候補の照合を検証する。
;; 実際のHLSからの応答・Corfuの自動表示は別途実機で確認する。

(ert-deftest my/eglot-haskell-qualified-bounds-excludes-module-prefix ()
  "T.unpのCAPF範囲はunpだけにする。"
  (with-temp-buffer
    (insert "T.unp")
    (should (equal
             (my/eglot-haskell-qualified-bounds
              (cons (point-min) (point-max)))
             (cons (+ (point-min) 2) (point-max))))))

(ert-deftest my/eglot-haskell-qualified-bounds-supports-nested-module ()
  "Data.Text.unpでは最後のドット以降だけを対象にする。"
  (with-temp-buffer
    (insert "Data.Text.unp")
    (pcase-let ((`(,beg . ,end)
                 (my/eglot-haskell-qualified-bounds
                  (cons (point-min) (point-max)))))
      (should (equal (buffer-substring-no-properties beg end) "unp")))))

(ert-deftest my/eglot-haskell-qualified-bounds-supports-empty-suffix ()
  "T.の直後でも補完範囲を空文字列にする。"
  (with-temp-buffer
    (insert "T.")
    (should (equal (my/eglot-haskell-qualified-bounds
                    (cons (point-min) (point-max)))
                   (cons (point) (point))))))

(ert-deftest my/eglot-haskell-qualified-bounds-preserves-unqualified-names ()
  "通常の名前・小文字のフィールド・数値は変更しない。"
  (dolist (text '("encode" "value.field" "3.14"))
    (with-temp-buffer
      (insert text)
      (let ((bounds (cons (point-min) (point-max))))
        (should (equal (my/eglot-haskell-qualified-bounds bounds)
                       bounds))))))

(ert-deftest my/eglot-haskell-qualified-completion-matches-unpack ()
  "HLSの候補unpackがT.unpの接尾辞unpと一致すること。"
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (insert "T.unp")
    ;; Eglotの実装と同じbounds-of-thing-at-point呼び出しを模擬する。
    (cl-letf (((symbol-function 'bounds-of-thing-at-point)
               (lambda (_thing) (cons (point-min) (point-max)))))
      (pcase-let* ((`(,beg ,end ,table)
                    (my/eglot-haskell-qualified-completion
                     (lambda ()
                       (pcase-let ((`(,from . ,to)
                                    (bounds-of-thing-at-point 'symbol)))
                         (list from to '("unpack" "unsafeHead"))))))
                   (prefix (buffer-substring-no-properties beg end)))
        (should (equal prefix "unp"))
        (should (member "unpack" (all-completions prefix table)))))))

(ert-deftest my/eglot-haskell-qualified-completion-leaves-other-modes-alone ()
  "他言語ではEglotのboundsに介入しない。"
  (with-temp-buffer
    (setq-local major-mode 'python-ts-mode)
    (insert "T.unp")
    (cl-letf (((symbol-function 'bounds-of-thing-at-point)
               (lambda (_thing) (cons (point-min) (point-max)))))
      (should (equal
               (my/eglot-haskell-qualified-completion
                (lambda () (bounds-of-thing-at-point 'symbol)))
               (cons (point-min) (point-max)))))))

;;; my-eglot-test.el ends here
