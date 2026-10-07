;;; my-development-test.el --- Tests for my-development -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-development' のテスト。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-development)


;;; HLS completion workaround -----------------------------------------------


(ert-deftest my/haskell-lsp-completion-trigger-p-detects-server-trigger ()
  "HLSが宣言した補完トリガーを検出すること。"
  (with-temp-buffer
    (insert "Text.")
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t))
              ((symbol-function 'lsp--capability-for-method)
               (lambda (_method) 'completion-options))
              ((symbol-function
                'lsp:completion-options-trigger-characters?)
               (lambda (_options) ["."]))
              ((symbol-function
                'lsp-completion--looking-back-trigger-characterp)
               (lambda (triggers)
                 (when (equal triggers ["."])
                   "."))))
      (should (equal (my/haskell-lsp-completion-trigger-p) ".")))))


(ert-deftest my/haskell-lsp-completion-trigger-p-ignores-other-modes ()
  "Haskell以外ではLSP補完トリガーを扱わないこと。"
  (cl-letf (((symbol-function 'derived-mode-p)
             (lambda (&rest _modes) nil)))
    (should-not (my/haskell-lsp-completion-trigger-p))))


(ert-deftest my/haskell-lsp-completion-fix-empty-prefix-keeps-known-start ()
  "lsp-modeが推測済みのprefix開始位置は変更しないこと。"
  (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
             (lambda () t)))
    (should (= (my/haskell-lsp-completion-fix-empty-prefix 42)
               42))))


(ert-deftest my/haskell-lsp-completion-fix-empty-prefix-uses-point-after-trigger ()
  "trigger直後でprefix開始位置がnilなら現在位置を使うこと。"
  (with-temp-buffer
    (insert "Text.")
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t)))
      (should (= (my/haskell-lsp-completion-fix-empty-prefix nil)
                 (point))))))


(ert-deftest my/haskell-lsp-completion-fix-empty-prefix-keeps-nil-without-trigger ()
  "trigger直後でなければnilのprefix開始位置を変更しないこと。"
  (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
             (lambda () nil)))
    (should-not (my/haskell-lsp-completion-fix-empty-prefix nil))))


(ert-deftest my/haskell-lsp-completion-reset-on-trigger-resets-session-and-cache ()
  "trigger入力時は進行中の補完とlsp-modeのcacheを破棄すること。"
  (let ((completion-in-region-mode t)
        completion-arg
        cache-cleared)
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t))
              ((symbol-function 'completion-in-region-mode)
               (lambda (arg)
                 (setq completion-arg arg)))
              ((symbol-function 'lsp-completion--clear-cache)
               (lambda (&optional _keep-last-result)
                 (setq cache-cleared t))))
      (my/haskell-lsp-completion-reset-on-trigger))
    (should (= completion-arg -1))
    (should cache-cleared)))


(ert-deftest my/haskell-lsp-completion-reset-on-trigger-does-nothing-otherwise ()
  "trigger以外の入力では補完セッションとcacheを変更しないこと。"
  (let ((completion-in-region-mode t)
        completion-called
        cache-cleared)
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () nil))
              ((symbol-function 'completion-in-region-mode)
               (lambda (_arg)
                 (setq completion-called t)))
              ((symbol-function 'lsp-completion--clear-cache)
               (lambda (&optional _keep-last-result)
                 (setq cache-cleared t))))
      (my/haskell-lsp-completion-reset-on-trigger))
    (should-not completion-called)
    (should-not cache-cleared)))


(ert-deftest my/haskell-lsp-completion-setup-manages-local-hook ()
  "lsp-completion-modeに合わせてbuffer-local hookを追加・削除すること。"
  (with-temp-buffer
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (setq-local lsp-completion-mode t)
      (my/haskell-lsp-completion-setup)
      (should
       (memq #'my/haskell-lsp-completion-reset-on-trigger
             post-self-insert-hook))

      (setq-local lsp-completion-mode nil)
      (my/haskell-lsp-completion-setup)
      (should-not
       (memq #'my/haskell-lsp-completion-reset-on-trigger
             post-self-insert-hook)))))


;;; my-development-test.el ends here
