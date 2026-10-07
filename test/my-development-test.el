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
               (lambda (_options) ["."]))
              ((symbol-function
                'lsp-completion--looking-back-trigger-characterp)
               (lambda (triggers)
                 (when (equal triggers ["."])
                   "."))))
      (should (equal (my/haskell-lsp-completion-trigger-p) ".")))))


(ert-deftest my/haskell-lsp-completion-trigger-p-ignores-disabled-lsp ()
  "lsp-completion-modeが無効ならtriggerを扱わないこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode nil)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (should-not (my/haskell-lsp-completion-trigger-p)))))


(ert-deftest my/haskell-lsp-completion--call-uses-empty-symbol-bounds-after-trigger ()
  "trigger直後ではlsp-modeへ空のsymbol boundsを渡すこと。"
  (with-temp-buffer
    (insert "Text.")
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t))
              ((symbol-function 'bounds-of-thing-at-point)
               (lambda (_thing)
                 '(1 . 2))))
      (let ((result
             (my/haskell-lsp-completion--call
              (lambda ()
                (bounds-of-thing-at-point 'symbol))
              nil)))
        (should (equal result (cons (point) (point))))))))


(ert-deftest my/haskell-lsp-completion--call-keeps-normal-bounds-without-trigger ()
  "trigger直後でなければ通常のsymbol boundsを変更しないこと。"
  (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
             (lambda () nil))
            ((symbol-function 'bounds-of-thing-at-point)
             (lambda (_thing)
               '(1 . 2))))
    (should
     (equal
      (my/haskell-lsp-completion--call
       (lambda ()
         (bounds-of-thing-at-point 'symbol))
       nil)
      '(1 . 2)))))


(ert-deftest my/haskell-lsp-completion-around-uses-buster-in-haskell ()
  "HaskellのLSP CAPFはCape busterで包むこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (let (buster-called)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _modes) t))
                ((symbol-function 'cape-wrap-buster)
                 (lambda (capf &optional _valid)
                   (setq buster-called t)
                   (funcall capf)))
                ((symbol-function 'my/haskell-lsp-completion--call)
                 (lambda (function args)
                   (apply function args))))
        (should
         (eq (my/haskell-lsp-completion-around
              (lambda () 'result))
             'result))
        (should buster-called)))))


(ert-deftest my/haskell-lsp-completion-around-skips-buster-outside-haskell ()
  "Haskell以外ではCape busterを適用しないこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (let (buster-called)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _modes) nil))
                ((symbol-function 'cape-wrap-buster)
                 (lambda (capf &optional _valid)
                   (setq buster-called t)
                   (funcall capf))))
        (should
         (eq (my/haskell-lsp-completion-around
              (lambda () 'result))
             'result))
        (should-not buster-called)))))


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
