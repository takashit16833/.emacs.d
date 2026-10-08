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


;;; Docker/TRAMP LSP transport ---------------------------------------------


(ert-deftest my/lsp-docker-direct-async-methods-changes-copy-only ()
  "Dockerのdirect async用引数だけコピー上で-iへ変更すること。"
  (let* ((methods
          '(("docker"
             (tramp-login-args
              (("exec") ("-it") ("%h") ("%l"))))
            ("ssh"
             (tramp-login-args
              (("-l") ("%u") ("%h"))))))
         (result (my/lsp-docker-direct-async-methods methods)))
    (should
     (equal
      (cadr
       (assq 'tramp-login-args
             (cdr (assoc "docker" result))))
      '(("exec") ("-i") ("%h") ("%l"))))
    (should
     (equal
      (cadr
       (assq 'tramp-login-args
             (cdr (assoc "docker" methods))))
      '(("exec") ("-it") ("%h") ("%l"))))
    (should
     (equal (assoc "ssh" result)
            (assoc "ssh" methods)))))


(ert-deftest my/lsp-start-workspace-with-docker-direct-async-scopes-settings ()
  "DockerのLSP起動中だけdirect async用設定を適用すること。"
  (let ((tramp-methods
         '(("docker"
            (tramp-login-args
             (("exec") ("-it") ("%h") ("%l"))))))
        (connection-local-default-application 'tramp)
        observed-application
        observed-args)
    (cl-letf (((symbol-function 'file-remote-p)
               (lambda (_file &optional identification)
                 (when (eq identification 'method)
                   "docker"))))
      (should
       (eq
        (my/lsp-start-workspace-with-docker-direct-async
         (lambda (_session _client _root &optional _initialization-options)
           (setq observed-application connection-local-default-application
                 observed-args
                 (cadr
                  (assq 'tramp-login-args
                        (cdr (assoc "docker" tramp-methods)))))
           'started)
         nil nil "/docker:test:/workspace" nil)
        'started)))
    (should (eq observed-application 'my-lsp))
    (should
     (equal observed-args
            '(("exec") ("-i") ("%h") ("%l"))))
    (should
     (equal
      (cadr
       (assq 'tramp-login-args
             (cdr (assoc "docker" tramp-methods))))
      '(("exec") ("-it") ("%h") ("%l"))))))


(ert-deftest my/lsp-start-workspace-with-docker-direct-async-leaves-local-alone ()
  "Docker以外のLSP起動ではTRAMP設定を変更しないこと。"
  (let ((tramp-methods
         '(("docker"
            (tramp-login-args
             (("exec") ("-it") ("%h") ("%l"))))))
        (connection-local-default-application 'tramp)
        observed-application
        observed-args)
    (cl-letf (((symbol-function 'file-remote-p)
               (lambda (&rest _args) nil)))
      (my/lsp-start-workspace-with-docker-direct-async
       (lambda (_session _client _root &optional _initialization-options)
         (setq observed-application connection-local-default-application
               observed-args
               (cadr
                (assq 'tramp-login-args
                      (cdr (assoc "docker" tramp-methods))))))
       nil nil "/tmp/project" nil))
    (should (eq observed-application 'tramp))
    (should
     (equal observed-args
            '(("exec") ("-it") ("%h") ("%l"))))))


;;; my-development-test.el ends here
