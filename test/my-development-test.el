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
    (setq-local lsp-completion-mode t)
    (insert "Text.")
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t))
              ((symbol-function 'lsp--capability-for-method)
               (lambda (_method) 'completion-options))
              ((symbol-function
                'lsp:completion-options-trigger-characters?)
               (lambda (_options) ["."])))
      (should (equal (my/haskell-lsp-completion-trigger-p) ".")))))


(ert-deftest my/haskell-lsp-completion-trigger-p-ignores-disabled-lsp ()
  "lsp-completion-modeが無効ならtriggerを扱わないこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode nil)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (should-not (my/haskell-lsp-completion-trigger-p)))))


(ert-deftest my/haskell-lsp-completion--call-capf-uses-empty-bounds-after-trigger ()
  "trigger直後ではlsp-modeへ空のsymbol boundsを渡すこと。"
  (with-temp-buffer
    (insert "Text.")
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t))
              ((symbol-function 'bounds-of-thing-at-point)
               (lambda (_thing)
                 '(1 . 2)))
              ((symbol-function 'lsp-completion-at-point)
               (lambda ()
                 (bounds-of-thing-at-point 'symbol))))
      (should
       (equal (my/haskell-lsp-completion--call-capf)
              (cons (point) (point)))))))


(ert-deftest my/haskell-lsp-completion--call-capf-keeps-normal-bounds ()
  "trigger直後でなければ通常のsymbol boundsを変更しないこと。"
  (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
             (lambda () nil))
            ((symbol-function 'lsp-completion-at-point)
             (lambda ()
               (bounds-of-thing-at-point 'symbol)))
            ((symbol-function 'bounds-of-thing-at-point)
             (lambda (_thing)
               '(1 . 2))))
    (should
     (equal (my/haskell-lsp-completion--call-capf)
            '(1 . 2)))))


(ert-deftest my/haskell-lsp-completion-at-point-uses-buster ()
  "Haskell用CAPFはCape busterで入力変更を検出すること。"
  (let (buster-capf)
    (cl-letf (((symbol-function 'cape-wrap-buster)
               (lambda (capf &optional _valid)
                 (setq buster-capf capf)
                 'wrapped-capf)))
      (should
       (eq (my/haskell-lsp-completion-at-point)
           'wrapped-capf))
      (should
       (eq buster-capf
           #'my/haskell-lsp-completion--call-capf)))))


(ert-deftest my/haskell-lsp-completion-reset-on-trigger-closes-session ()
  "trigger入力時は進行中の補完セッションを終了すること。"
  (let ((completion-in-region-mode t)
        completion-arg)
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t))
              ((symbol-function 'completion-in-region-mode)
               (lambda (arg)
                 (setq completion-arg arg))))
      (my/haskell-lsp-completion-reset-on-trigger))
    (should (= completion-arg -1))))


(ert-deftest my/haskell-lsp-completion-reset-on-trigger-does-nothing-otherwise ()
  "trigger以外の入力では補完セッションを変更しないこと。"
  (let ((completion-in-region-mode t)
        completion-called)
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () nil))
              ((symbol-function 'completion-in-region-mode)
               (lambda (_arg)
                 (setq completion-called t))))
      (my/haskell-lsp-completion-reset-on-trigger))
    (should-not completion-called)))


(ert-deftest my/haskell-lsp-completion-setup-replaces-only-haskell-capf ()
  "Haskellでは標準LSP CAPFだけを専用CAPFへ差し替えること。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point
                  tags-completion-at-point-function))
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (my/haskell-lsp-completion-setup)
      (should
       (eq (car completion-at-point-functions)
           #'my/haskell-lsp-completion-at-point))
      (should-not
       (memq #'lsp-completion-at-point
             completion-at-point-functions))
      (should
       (memq #'tags-completion-at-point-function
             completion-at-point-functions))
      (should
       (memq #'my/haskell-lsp-completion-reset-on-trigger
             post-self-insert-hook)))))


(ert-deftest my/haskell-lsp-completion-setup-leaves-other-modes-alone ()
  "Haskell以外では標準LSP CAPFを変更しないこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point
                  tags-completion-at-point-function))
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) nil)))
      (my/haskell-lsp-completion-setup)
      (should
       (equal completion-at-point-functions
              '(lsp-completion-at-point
                tags-completion-at-point-function)))
      (should-not
       (memq #'my/haskell-lsp-completion-reset-on-trigger
             post-self-insert-hook)))))


;;; my-development-test.el ends here
