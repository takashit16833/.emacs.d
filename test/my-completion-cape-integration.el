;;; my-completion-cape-integration.el --- Cape/LSP completion integration -*- lexical-binding: t; -*-
;;; Commentary:
;; 実際のCapeを使い、候補統合とLSP由来の確定処理を検証する。
;; 実行例:
;; emacs -Q --batch -L elisp --eval '(package-initialize)' \
;;   -l test/my-completion-cape-integration.el \
;;   -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'dabbrev)
(require 'cape)
(require 'my-completion)

(ert-deftest my/lsp-dabbrev-integration-merges-and-preserves-lsp-actions ()
  "同じ候補一覧に両方を載せ、LSPの確定処理を維持する。"
  (with-temp-buffer
    (insert "userProfile = 1\nuser")
    (let ((dabbrev-case-replace nil)
          (dabbrev-case-fold-search nil)
          completed)
      (setq-local my/lsp-dabbrev-source-capf
                  (lambda ()
                    (list (- (point) 4) (point) '("userName")
                          :category 'lsp-capf
                          :company-kind (lambda (_) 'function)
                          :annotation-function (lambda (_) " LSP")
                          :exit-function
                          (lambda (candidate status)
                            (setq completed (list candidate status))))))
      (pcase-let* ((`(,beg ,end ,table . ,props)
                    (my/lsp-dabbrev-capf))
                   (candidates (all-completions "user" table)))
        (should (equal (buffer-substring-no-properties beg end) "user"))
        (should (eq (plist-get props :category) 'lsp-capf))
        (should (member "userName" candidates))
        (should (member "userProfile" candidates))
        ;; 統合後も、LSP由来の種類とdabbrev由来のTextを区別する。
        (let ((kind (plist-get props :company-kind)))
          (should (eq (funcall kind "userName") 'function))
          (should (eq (funcall kind "userProfile") 'text)))
        ;; 本体と同じexit-functionを透過していること。
        (funcall (plist-get props :exit-function) "userName" 'finished)
        (should (equal completed '("userName" finished)))))))

(ert-deftest my/lsp-dabbrev-integration-keeps-qualified-completion ()
  "Text.unpのような補完位置でもLSP候補を失わないこと。"
  (with-temp-buffer
    (insert "unplug = 1\nText.unp")
    (let ((dabbrev-case-replace nil)
          (dabbrev-case-fold-search nil))
      (setq-local my/lsp-dabbrev-source-capf
                  (lambda ()
                    (list (- (point) 3) (point) '("unpack")
                          :category 'lsp-capf)))
      (pcase-let* ((`(,beg ,end ,table . ,props)
                    (my/lsp-dabbrev-capf))
                   (candidates (all-completions "unp" table)))
        (should (equal (buffer-substring-no-properties beg end) "unp"))
        (should (member "unpack" candidates))
        (should (member "unplug" candidates))
        (should (eq (plist-get props :category) 'lsp-capf))))))

(ert-deftest my/lsp-dabbrev-integration-preserves-lsp-passthrough ()
  "サーバーが返したprefix非一致候補も勝手に除外しないこと。"
  (with-temp-buffer
    (insert "Text.unp")
    (setq-local my/lsp-dabbrev-source-capf
                (lambda ()
                  (list (- (point) 3) (point) '("serverChosenText")
                        :category 'lsp-capf)))
    (pcase-let* ((`(,_beg ,_end ,table . ,props)
                  (my/lsp-dabbrev-capf))
                 (candidates (all-completions "unp" table)))
      (should (member "serverChosenText" candidates))
      (should (eq (plist-get props :category) 'lsp-capf)))))

(ert-deftest my/lsp-dabbrev-integration-skips-phrase-completion ()
  "空白直後はdabbrevを呼ばず、複数語候補を出さないこと。"
  (with-temp-buffer
    (insert "topKeys k results =\nhitAt k relevant results =\n"
            "reciprocalRankAt k ")
    (setq-local my/lsp-dabbrev-source-capf
                (lambda () nil))
    (should-not (my/lsp-dabbrev-capf))))

(ert-deftest my/lsp-dabbrev-integration-prefers-lsp-on-name-collision ()
  "同名のdabbrevだけを除外し、LSP候補と固有の単語を残す。"
  (with-temp-buffer
    (insert "userName = 1\nuserProfile = 2\nuser")
    (let ((dabbrev-case-replace nil)
          (dabbrev-case-fold-search nil)
          (lsp-reads 0)
          completed)
      (setq-local my/lsp-dabbrev-source-capf
                  (lambda ()
                    (list (- (point) 4) (point)
                          (lambda (str pred action)
                            (when (eq action t)
                              (cl-incf lsp-reads))
                            (complete-with-action
                             action '("userName" "userRemote") str pred))
                          :category 'lsp-capf
                          :company-kind (lambda (_) 'function)
                          :exit-function
                          (lambda (candidate status)
                            (setq completed (list candidate status))))))
      (pcase-let* ((`(,_beg ,_end ,table . ,props)
                    (my/lsp-dabbrev-capf))
                   (candidates (all-completions "user" table))
                   (kind (plist-get props :company-kind)))
        (should (= 1 (cl-count "userName" candidates :test #'string=)))
        (should (member "userRemote" candidates))
        (should (member "userProfile" candidates))
        (should (eq (funcall kind "userName") 'function))
        (should (eq (funcall kind "userProfile") 'text))
        ;; LSP候補を重複確認用に再取得しない。
        (should (= lsp-reads 1))
        (funcall (plist-get props :exit-function) "userName" 'finished)
        (should (equal completed '("userName" finished)))))))

(ert-deftest my/lsp-dabbrev-integration-preserves-duplicate-lsp-candidates ()
  "同名のLSP候補は残し、dabbrev由来の重複だけを削る。"
  (with-temp-buffer
    (insert "userName = 1\nuser")
    (let ((dabbrev-case-replace nil)
          (dabbrev-case-fold-search nil))
      (setq-local my/lsp-dabbrev-source-capf
                  (lambda ()
                    (list (- (point) 4) (point)
                          (lambda (_str _pred action)
                            (when (eq action t)
                              '("userName" "userName")))
                          :category 'lsp-capf)))
      (pcase-let* ((`(,_beg ,_end ,table . ,_)
                    (my/lsp-dabbrev-capf))
                   (candidates (all-completions "user" table)))
        (should (= 2 (cl-count "userName" candidates
                               :test #'string=)))))))

;;; my-completion-cape-integration.el ends here
