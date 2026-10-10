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
                    'dabbrev))))))

(ert-deftest my/dabbrev-completion-setup-preserves-existing-capfs ()
  "既存CAPFの順番を保ち、重複なく最後に追加すること。"
  (with-temp-buffer
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point other-capf))
    (my/dabbrev-completion-setup)
    (my/dabbrev-completion-setup)
    (should (equal completion-at-point-functions
                   '(lsp-completion-at-point other-capf my/dabbrev-capf)))))

(ert-deftest my/lsp-dabbrev-completion-setup-prefers-haskell ()
  "Haskell固有CAPFを統合元にし、他のCAPFを残すこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point
                  my/haskell-lsp-completion-at-point
                  tags-completion-at-point-function
                  my/dabbrev-capf))
    (my/lsp-dabbrev-completion-setup)
    (should (eq my/lsp-dabbrev-source-capf
                #'my/haskell-lsp-completion-at-point))
    (should (equal completion-at-point-functions
                   '(my/lsp-dabbrev-capf
                     tags-completion-at-point-function
                     my/dabbrev-capf)))
    ;; 同じhookが再実行されても統合CAPFを重複登録しない。
    (my/lsp-dabbrev-completion-setup)
    (should (equal completion-at-point-functions
                   '(my/lsp-dabbrev-capf
                     tags-completion-at-point-function
                     my/dabbrev-capf)))))

(ert-deftest my/lsp-dabbrev-completion-setup-keeps-standard-lsp ()
  "Haskell以外は標準のLSP CAPFを統合元にすること。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point my/dabbrev-capf))
    (my/lsp-dabbrev-completion-setup)
    (should (eq my/lsp-dabbrev-source-capf #'lsp-completion-at-point))
    (should (equal completion-at-point-functions
                   '(my/lsp-dabbrev-capf my/dabbrev-capf)))))

(ert-deftest my/lsp-dabbrev-completion-setup-cleans-up-on-disable ()
  "LSP無効時は統合CAPFと元CAPFの参照を片付けること。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point my/dabbrev-capf))
    (my/lsp-dabbrev-completion-setup)
    (setq-local lsp-completion-mode nil)
    (my/lsp-dabbrev-completion-setup)
    (should-not my/lsp-dabbrev-source-capf)
    (should (equal completion-at-point-functions '(my/dabbrev-capf)))))

;;; my-completion-test.el ends here
