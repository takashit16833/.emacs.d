;;; my-completion-test.el --- Tests for my-completion -*- lexical-binding: t; -*-
;;; Commentary:
;; dabbrevの補完位置と、既存CAPFへの影響を確認する。

;;; Code:

(require 'ert)
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

;;; my-completion-test.el ends here
