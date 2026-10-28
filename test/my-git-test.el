;;; my-git-test.el --- Tests for Git and Magit helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Magitの更新通知で差分キャッシュとdiff-hlが従来どおり更新されるかを確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-git)

(defvar diff-hl-disable-on-remote)

(ert-deftest my/magit-refresh-tab-line-git-status-includes-renamed-files ()
  "Magitの変更・rename結果をtab-lineキャッシュへ渡す。"
  (let (received)
    (cl-letf (((symbol-function 'magit-toplevel)
               (lambda () "/project/"))
              ((symbol-function 'magit-file-status)
               (lambda (&rest args)
                 (should (equal args '("--untracked-files=no")))
                 '(("modified.el") ("new-name.el" "old-name.el"))))
              ((symbol-function 'my/tab-line-update-git-modified-cache)
               (lambda (root files)
                 (setq received (cons root files)))))
      (my/magit-refresh-tab-line-git-status)
      (should (equal (car received) "/project/"))
      (should (equal (cdr received)
                     '("old-name.el" "new-name.el" "modified.el"))))))

(ert-deftest my/magit-refresh-tab-line-git-status-skips-without-root ()
  "MagitのルートがなければGit問い合わせとキャッシュ更新をしない。"
  (cl-letf (((symbol-function 'magit-toplevel) (lambda () nil))
            ((symbol-function 'magit-file-status)
             (lambda (&rest _) (ert-fail "Unexpected Git query")))
            ((symbol-function 'my/tab-line-update-git-modified-cache)
             (lambda (&rest _) (ert-fail "Unexpected cache update"))))
    (my/magit-refresh-tab-line-git-status)))

(ert-deftest my/diff-hl-magit-post-refresh-overrides-remote-temporarily ()
  "Magit更新中だけリモート制限を解除し、元の設定を復元する。"
  (let ((diff-hl-disable-on-remote t)
        (observed :not-called))
    (cl-letf (((symbol-function 'diff-hl-magit-post-refresh)
               (lambda ()
                 (setq observed diff-hl-disable-on-remote))))
      (my/diff-hl-magit-post-refresh)
      (should-not observed)
      (should diff-hl-disable-on-remote))))

;;; my-git-test.el ends here
