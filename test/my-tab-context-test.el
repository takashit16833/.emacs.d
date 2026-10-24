;;; my-tab-context-test.el --- Tab-context Dirvish tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Dirvishの再利用時にも編集ファイルへの追従が行われることを確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-tab-context)

;; パッケージを読み込まずに関数を差し替えてテストできるようにする。
(autoload 'dirvish "dirvish")
(autoload 'dirvish-subtree-expand-to "dirvish-subtree")
(autoload 'dirvish--redisplay "dirvish")


(ert-deftest my/project-dirvish-follows-each-file-on-session-reuse ()
  "同一のDirvish一覧を再利用しても、既存ツリー内の別ファイルに移動する。"
  (let* ((root (make-temp-file "my-dirvish-follow-" t))
         (first-file (expand-file-name "elisp/first.el" root))
         (second-file (expand-file-name "elisp/second.el" root))
         (dirvish-buf (generate-new-buffer " *my-dirvish-reuse-test*"))
         (redraws 0)
         selected-files)
    (unwind-protect
        (save-window-excursion
          (make-directory (file-name-directory first-file) t)
          (dolist (file (list first-file second-file))
            (with-temp-file file (insert "test")))
          ;; Dirvishでサブツリーが展開済みの状態を2行で模擬する。
          (with-current-buffer dirvish-buf
            (insert "first.el\nsecond.el\n")
            (setq-local major-mode 'dired-mode)
            (setq-local default-directory root))
          (let ((features (cons 'dirvish-subtree features)))
            (cl-letf (((symbol-function 'my/tab-context-directory)
                       (lambda () root))
                      ((symbol-function 'dirvish)
                       (lambda (_root) (switch-to-buffer dirvish-buf)))
                      ((symbol-function 'dired-get-filename)
                       (lambda (&rest _args)
                         (pcase (buffer-substring-no-properties
                                 (line-beginning-position)
                                 (line-end-position))
                           ("first.el" first-file)
                           ("second.el" second-file))))
                      ((symbol-function 'dirvish-subtree-expand-to)
                       (lambda (_target)
                         (ert-fail "Already visible file must not expand")))
                      ((symbol-function 'dirvish--redisplay)
                       (lambda () (cl-incf redraws))))
              (dolist (file (list first-file second-file))
                (with-temp-buffer
                  (setq-local buffer-file-name file)
                  (switch-to-buffer (current-buffer))
                  (my/project-dirvish)
                  (push (dired-get-filename nil t) selected-files)))
              (should (equal (nreverse selected-files)
                             (list first-file second-file)))
              (should (= redraws 2)))))
      (when (buffer-live-p dirvish-buf)
        (kill-buffer dirvish-buf))
      (delete-directory root t))))


(ert-deftest my/dirvish-goto-file-expands-hidden-file ()
  "未展開のファイルだけ親ツリーを展開し、実際の選択位置を確認する。"
  (with-temp-buffer
    (insert "other.el\n")
    (let ((target "/tmp/example/target.el")
          (expansions 0))
      (cl-letf (((symbol-function 'dired-get-filename)
                 (lambda (&rest _args)
                   (if (looking-at-p "target.el")
                       target "/tmp/example/other.el")))
                ((symbol-function 'dirvish-subtree-expand-to)
                 (lambda (_file)
                   (cl-incf expansions)
                   (goto-char (point-max))
                   (insert "target.el\n")
                   (forward-line -1)
                   target)))
        (should (my/tab-context--dirvish-goto-file target))
        (should (equal (dired-get-filename nil t) target))
        (should (= expansions 1))))))




;;; my-tab-context-test.el ends here
