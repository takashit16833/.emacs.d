;;; my-python-test.el --- Python helper tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Basedpyrightのプロジェクトローカル優先とPATHへのフォールバックを確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-python)


(ert-deftest my/eglot-python-server-prefers-project-venv ()
  "プロジェクトの仮想環境にあるBasedpyrightを優先する。"
  (cl-letf (((symbol-function 'project-current)
             (lambda (&optional _maybe-prompt _directory) 'project))
            ((symbol-function 'project-root)
             (lambda (_project) "/tmp/project/"))
            ((symbol-function 'file-executable-p)
             (lambda (file)
               (equal file
                      "/tmp/project/.venv/bin/basedpyright-langserver")))
            ((symbol-function 'executable-find)
             (lambda (_command)
               (ert-fail "PATHを探索してはならない"))))
    (should
     (equal (my/eglot-python-server nil)
            '("/tmp/project/.venv/bin/basedpyright-langserver" "--stdio")))))


(ert-deftest my/eglot-python-server-falls-back-to-path ()
  "プロジェクトローカルにない場合はPATH上のBasedpyrightを使う。"
  (cl-letf (((symbol-function 'project-current)
             (lambda (&optional _maybe-prompt _directory) nil))
            ((symbol-function 'executable-find)
             (lambda (command)
               (when (equal command "basedpyright-langserver")
                 "/usr/bin/basedpyright-langserver"))))
    (should
     (equal (my/eglot-python-server nil)
            '("/usr/bin/basedpyright-langserver" "--stdio")))))


(ert-deftest my/eglot-python-server-reports-missing-command ()
  "Basedpyrightが見つからない場合は利用者向けエラーにする。"
  (cl-letf (((symbol-function 'project-current)
             (lambda (&optional _maybe-prompt _directory) nil))
            ((symbol-function 'executable-find)
             (lambda (_command) nil)))
    (should-error (my/eglot-python-server nil) :type 'user-error)))


;;; my-python-test.el ends here
