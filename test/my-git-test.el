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


(ert-deftest my/git-editor-setup-preserves-origin-and-hooks ()
  "Git エディタの初期化で元の Tab と終了フックを保存する。"
  (let* ((origin '(project . "/tmp/sample-project/"))
         (target '(tab (name . "project")))
         (buffer (generate-new-buffer " *git-editor-test*"))
         (selected nil))
    (unwind-protect
        (cl-letf (((symbol-function 'tab-router-current-id)
                   (lambda () origin))
                  ((symbol-function 'tab-router-find-tab-by-id)
                   (lambda (id) (when (equal id origin) target)))
                  ((symbol-function 'tab-bar-tabs)
                   (lambda (&optional _) (list '(current-tab) target)))
                  ((symbol-function 'tab-bar-select-tab)
                   (lambda (index) (setq selected index))))
          (with-current-buffer buffer
            (setq buffer-file-name "/tmp/sample-project/.git/COMMIT_EDITMSG")
            (setq-local with-editor-mode t
                        with-editor-pre-finish-hook nil
                        with-editor-pre-cancel-hook nil
                        with-editor-post-finish-hook nil
                        with-editor-post-cancel-hook nil)
            (my/git-editor-setup)
            (should (equal my/git-editor-origin-tab origin))
            (should (memq #'my/git-editor-skip-window-restore
                          with-editor-pre-finish-hook))
            (should (memq #'my/git-editor-skip-window-restore
                          with-editor-pre-cancel-hook))
            (let ((on-finish (car with-editor-post-finish-hook))
                  (on-cancel (car with-editor-post-cancel-hook)))
              (should (functionp on-finish))
              (should (functionp on-cancel))
              ;; 再初期化しても終了 hook を重複登録しない。
              (my/git-editor-setup)
              (should (= (length with-editor-post-finish-hook) 1))
              (funcall on-finish)
              (should (= selected 2))
              (setq selected nil)
              (funcall on-cancel)
              (should (= selected 2)))))
      (kill-buffer buffer))))


(ert-deftest my/git-editor-setup-ignores-regular-files ()
  "通常のファイルや非 with-editor バッファには何も登録しない。"
  (with-temp-buffer
    (setq buffer-file-name "/tmp/sample-project/main.el")
    (setq-local with-editor-mode t
                with-editor-pre-finish-hook nil)
    (my/git-editor-setup)
    (should-not (local-variable-p 'my/git-editor-origin-tab))
    (should-not with-editor-pre-finish-hook)))


(ert-deftest my/git-editor-skip-window-restore-only-in-misc ()
  "Misc での編集終了時だけ、別 Tab の保存済み画面を復元しない。"
  (with-temp-buffer
    (cl-letf (((symbol-function 'tab-router-current-id)
               (lambda () 'misc)))
      (setq-local with-editor-previous-winconf :project-layout)
      (my/git-editor-skip-window-restore)
      (should-not with-editor-previous-winconf))
    (cl-letf (((symbol-function 'tab-router-current-id)
               (lambda () '(project . "/tmp/sample-project/"))))
      (setq-local with-editor-previous-winconf :project-layout)
      (my/git-editor-skip-window-restore)
      (should (eq with-editor-previous-winconf :project-layout)))))


(ert-deftest my/git-editor-return-to-tab-ignores-closed-tabs ()
  "編集中に元の Tab が閉じてもエラーにしない。"
  (cl-letf (((symbol-function 'tab-router-find-tab-by-id)
             (lambda (_) nil))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (_) (ert-fail "Closed tab selected"))))
    (should-not (my/git-editor-return-to-tab 'missing))))


;;; my-git-test.el ends here
