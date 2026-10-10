;;; my-completion-test.el --- Tests for my-completion -*- lexical-binding: t; -*-
;;; Commentary:
;; dabbrevの補完位置と、既存CAPFへの影響を確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
;; `dabbrev-case-replace' を動的束縛するため、ERTの定義前に宣言を読み込む。
(require 'dabbrev)
(require 'my-completion)

(ert-deftest my/dabbrev-capf-skips-whitespace ()
  "空白や改行の直後では直前の単語に遡らないこと。"
  (dolist (space '(" " "\t" "\n"))
    (with-temp-buffer
      (insert "topKeys k results =\nhitAt k relevant results =\n"
              "reciprocalRankAt k" space)
      (should-not (my/dabbrev-capf)))))

(ert-deftest my/dabbrev-capf-skips-punctuation-and-empty-buffer ()
  "記号の直後とバッファ先頭では補完しないこと。"
  (with-temp-buffer
    (should-not (my/dabbrev-capf))
    (insert "userN.")
    (should-not (my/dabbrev-capf))))

(ert-deftest my/dabbrev-capf-offers-single-word-candidates ()
  "単語の途中ならバッファ内の単語を候補に出すこと。"
  (with-temp-buffer
    (insert "userName = 1\nuserProfile = 2\nuserN")
    ;; emacs -Qではcompletion.elを読み込まないため、実際の設定を再現する。
    (let ((dabbrev-case-replace nil))
      (pcase-let ((`(,beg ,end ,table . ,props) (my/dabbrev-capf)))
        (should (equal (buffer-substring-no-properties beg end) "userN"))
        (should (member "userName" (all-completions "userN" table)))
        (should (eq (funcall (plist-get props :company-kind) "userName")
                    'text))))))

(ert-deftest my/dabbrev-completion-setup-preserves-existing-capfs ()
  "既存CAPFの順番を保ち、重複なく最後に追加すること。"
  (with-temp-buffer
    (setq-local completion-at-point-functions
                '(primary-capf secondary-capf))
    (my/dabbrev-completion-setup)
    (my/dabbrev-completion-setup)
    (should (equal completion-at-point-functions
                   '(primary-capf secondary-capf my/dabbrev-capf)))))

(ert-deftest my/eglot-dabbrev-tracking-preserves-original-candidates ()
  "HLS由来の文字列プロパティを失わず、重複判定用の名前だけ記録する。"
  (with-temp-buffer
    (let* ((candidate (propertize "encode" 'eglot--lsp-item
                                  '(:command (:command "extendImport"))))
           (names (make-hash-table :test #'equal))
           (capf (my/eglot-dabbrev--track-candidates
                  (lambda () (list 1 1 (list candidate))) names))
           (found (all-completions "enc" (nth 2 capf))))
      (should (= (length found) 1))
      (should (gethash "encode" names))
      (should (equal (get-text-property 0 'eglot--lsp-item (car found))
                     '(:command (:command "extendImport")))))))

(ert-deftest my/eglot-dabbrev-setup-preserves-other-capfs ()
  "EglotのCAPFだけを統合版へ差し替え、再接続でも重複しない。"
  (with-temp-buffer
    (setq-local completion-at-point-functions
                '(eglot-completion-at-point tags-capf my/dabbrev-capf))
    (cl-letf (((symbol-function 'eglot-managed-p) (lambda () t)))
      (my/eglot-dabbrev-completion-setup)
      (my/eglot-dabbrev-completion-setup))
    (should (equal completion-at-point-functions
                   '(my/eglot-dabbrev-capf tags-capf my/dabbrev-capf)))
    (cl-letf (((symbol-function 'eglot-managed-p) (lambda () nil)))
      (my/eglot-dabbrev-completion-setup))
    (should (equal completion-at-point-functions
                   '(tags-capf my/dabbrev-capf)))))

;;; my-completion-test.el ends here
