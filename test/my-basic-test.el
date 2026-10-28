;;; my-basic-test.el --- Tests for basic Emacs utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; 設定のバイトコンパイル時に古い .elc を優先しないことを検証する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-basic)


(ert-deftest my/byte-compile-config-prefers-newer-sources ()
  "コンパイル中は新しいソースを優先し、終了後は設定値を元に戻す。"
  (let ((user-emacs-directory (make-temp-file "my-basic-test-" t))
        (load-prefer-newer nil)
        observed)
    (unwind-protect
        (progn
          (make-directory (expand-file-name "elisp" user-emacs-directory))
          (make-directory (expand-file-name "config" user-emacs-directory))
          (with-temp-file (expand-file-name "elisp/example.el"
                                            user-emacs-directory)
            (insert "(provide 'example)\n"))
          (cl-letf (((symbol-function 'byte-compile-file)
                     (lambda (_file)
                       (setq observed load-prefer-newer)
                       t)))
            (should (= (my/byte-compile-config) 1))
            (should observed))
          (should-not load-prefer-newer))
      (delete-directory user-emacs-directory t))))


;;; my-basic-test.el ends here
