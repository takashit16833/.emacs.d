;;; my-eglot-dabbrev-integration.el --- Eglot/Cape補完統合の結合ERT -*- lexical-binding: t; -*-

;;; Commentary:
;; HLS実機なしでCapeによる候補統合と候補に付いた編集情報を確認する。
;; Eglot/HLSの通信やT.unpでの実際の補完応答は検証していない。
;; Eglotの候補選択時は元のexit-functionとCompletionItem.commandが
;; 生きていること、dabbrev由来の候補はText種類として残ることを検証する。
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'cape)
(require 'my-completion)
(require 'my-eglot)

(ert-deftest my/eglot-dabbrev-merge-prefers-eglot-on-duplicate ()
  "同名候補ではEglotの元データを優先し、dabbrevの独自候補も残す。"
  (with-temp-buffer
    (insert "en")
    (let* ((beg (point-min))
           (end (point))
           (item '(:label "encode" :command (:command "extendImport")))
           (eglot-candidate (propertize "encode" 'eglot--lsp-item item))
           (eglot-exited nil))
      (cl-letf (((symbol-function 'eglot-completion-at-point)
                 (lambda ()
                   (list beg end (list eglot-candidate "encoder")
                         :exit-function
                         (lambda (_candidate status)
                           (setq eglot-exited status))
                         :company-kind (lambda (_candidate) 'function))))
                ((symbol-function 'my/dabbrev-capf)
                 (lambda ()
                   (list beg end '("encode" "enrich")
                         :company-kind (lambda (_candidate) 'text)))))
        (pcase-let* ((`(,_beg ,_end ,table . ,props)
                      (my/eglot-dabbrev-capf))
                     (candidates (all-completions "en" table))
                     (encode (cl-find "encode" candidates :test #'string=))
                     (enrich (cl-find "enrich" candidates :test #'string=)))
          (should (= 1 (cl-count "encode" candidates :test #'string=)))
          (should enrich)
          (should (equal (get-text-property 0 'eglot--lsp-item encode) item))
          (should (eq 'function
                      (funcall (plist-get props :company-kind) encode)))
          (should (eq 'text
                      (funcall (plist-get props :company-kind) enrich)))
          (funcall (plist-get props :exit-function) encode 'finished)
          (should (eq eglot-exited 'finished)))))))

(ert-deftest my/eglot-dabbrev-merge-does-not-hide-qualified-eglot-candidates ()
  "HLSが返すunpack候補を統合処理で消さない。"
  (with-temp-buffer
    (insert "T.unp")
    (let ((beg (+ (point-min) 2))
          (end (point)))
      (cl-letf (((symbol-function 'eglot-completion-at-point)
                 (lambda () (list beg end '("unpack" "unpackCString"))))
                ((symbol-function 'my/dabbrev-capf)
                 (lambda () (list beg end '("unique" "unpack")))))
        (pcase-let* ((`(,_beg ,_end ,table . ,_props)
                      (my/eglot-dabbrev-capf))
                     (candidates (all-completions "unp" table)))
          (should (member "unpack" candidates))
          (should (= 1 (cl-count "unpack" candidates :test #'string=))))))))

(ert-deftest my/eglot-dabbrev-merge-keeps-hls-auto-import-command ()
  "同名のdabbrev候補があってもHLSの自動importコマンドを維持する。"
  (with-temp-buffer
    (setq-local major-mode 'haskell-ts-mode)
    (insert "enc")
    (let* ((beg (point-min))
           (end (point))
           (item '(:label "encode"
                   :command (:title "extend import" :command "extendImport")))
           (candidate (propertize "encode" 'eglot--lsp-item item))
           (events nil))
      (cl-letf (((symbol-function 'eglot-current-server)
                 (lambda () 'test-hls))
                ((symbol-function 'eglot-execute)
                 (lambda (server action)
                   (should (eq server 'test-hls))
                   (should (equal (plist-get action :command) "extendImport"))
                   (push 'command events)))
                ((symbol-function 'eglot-completion-at-point)
                 (lambda ()
                   (my/eglot-haskell-completion-command
                    (list beg end (list candidate)
                          :exit-function
                          (lambda (_candidate _status)
                            (push 'eglot-exit events))))))
                ((symbol-function 'my/dabbrev-capf)
                 (lambda () (list beg end '("encode" "encoderLocal")))))
        (pcase-let* ((`(,_ ,_ ,table . ,props) (my/eglot-dabbrev-capf))
                     (choices (all-completions "enc" table))
                     (chosen (cl-find "encode" choices :test #'string=)))
          (should (= (cl-count "encode" choices :test #'string=) 1))
          (should chosen)
          (should (get-text-property 0 'eglot--lsp-item chosen))
          (funcall (plist-get props :exit-function) chosen 'finished)
          (should (equal (nreverse events) '(eglot-exit command))))))))

(ert-deftest my/eglot-dabbrev-merge-respects-eglot-prefix-filter ()
  "修飾名の補完時、無関係なHLS候補を素通ししない。"
  (with-temp-buffer
    (insert "T.unp")
    (let ((beg (+ (point-min) 2))
          (end (point)))
      (cl-letf (((symbol-function 'eglot-completion-at-point)
                 (lambda () (list beg end '("unpack" "unrelated"))))
                ((symbol-function 'my/dabbrev-capf)
                 (lambda () (list beg end '("unpack" "unique")))))
        (pcase-let* ((`(,_ ,_ ,table . ,_props) (my/eglot-dabbrev-capf))
                     (choices (all-completions "unp" table)))
          (should (member "unpack" choices))
          (should-not (member "unrelated" choices))
          (should (= (cl-count "unpack" choices :test #'string=) 1)))))))

(ert-deftest my/eglot-dabbrev-merge-uses-dabbrev-when-eglot-empty ()
  "Eglot候補がない場合はdabbrev候補を利用できる。"
  (with-temp-buffer
    (insert "uniq")
    (let ((beg (point-min))
          (end (point)))
      (cl-letf (((symbol-function 'eglot-completion-at-point)
                 (lambda () (list beg end nil)))
                ((symbol-function 'my/dabbrev-capf)
                 (lambda () (list beg end '("unique")))))
        (pcase-let ((`(,_ ,_ ,table . ,_) (my/eglot-dabbrev-capf)))
          (should (member "unique" (all-completions "uniq" table))))))))

;;; my-eglot-dabbrev-integration.el ends here
