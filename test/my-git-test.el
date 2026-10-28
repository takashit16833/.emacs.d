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

(ert-deftest my/magit-register-commit-message-handler-precedes-magit ()
  "Magit の汎用コミット編集ルールより COMMIT_EDITMSG 専用ルールを優先する。"
  (let ((with-editor-server-window-alist
         '(("/COMMIT_EDITMSG\\'" . switch-to-buffer))))
    (my/magit-register-commit-message-handler)
    (let* ((file "/work/project/.git/COMMIT_EDITMSG")
           (matched
            (seq-find (lambda (entry)
                        (string-match-p (car entry) file))
                      with-editor-server-window-alist)))
      (should (eq (cdr matched) #'my/magit-display-commit-message)))
    (should (= (length with-editor-server-window-alist) 2))
    ;; 二重登録されても同じルールを重複させない。
    (my/magit-register-commit-message-handler)
    (should (= (length with-editor-server-window-alist) 2))))


(ert-deftest my/magit-display-commit-message-routes-to-misc-and-returns ()
  "コミット編集は Misc へ移し、完了・取消後は元の Tab に戻る。"
  (let* ((buffer (generate-new-buffer " *my-git-commit-test*"))
         (origin '(project . "/work/project/"))
         (project-tab `(tab (tab-router-id . ,origin)))
         (tabs (list '(current-tab (tab-router-id . misc)) project-tab))
         (original-finish (lambda () :original-finish))
         (original-cancel (lambda () :original-cancel))
         destination displayed finish-hook cancel-hook selected)
    (unwind-protect
        (cl-letf (((symbol-function 'tab-router-current-id)
                   (lambda () origin))
                  ((symbol-function 'tab-router--select-destination)
                   (lambda (value) (setq destination value)))
                  ((symbol-function 'current-window-configuration)
                   (lambda (&rest _) :misc-layout))
                  ((symbol-function 'switch-to-buffer)
                   (lambda (value &rest _) (setq displayed value)))
                  ((symbol-function 'tab-router-find-tab-by-id)
                   (lambda (id) (and (equal id origin) project-tab)))
                  ((symbol-function 'tab-bar-tabs)
                   (lambda (&optional _) tabs))
                  ((symbol-function 'tab-bar-select-tab)
                   (lambda (number) (setq selected number))))
          (with-current-buffer buffer
            (setq-local with-editor-previous-winconf :project-layout)
            ;; Magit/with-editor の既存 hook があっても維持する。
            (setq-local with-editor-post-finish-hook (list original-finish))
            (setq-local with-editor-post-cancel-hook (list original-cancel)))
          (my/magit-display-commit-message buffer)
          (should (equal destination '(:id misc :name "Misc" :directory nil)))
          (should (eq displayed buffer))
          (should (eq (buffer-local-value 'with-editor-previous-winconf buffer)
                      :misc-layout))
          (setq finish-hook (buffer-local-value 'with-editor-post-finish-hook buffer)
                cancel-hook (buffer-local-value 'with-editor-post-cancel-hook buffer))
          (should (= (length finish-hook) 2))
          (should (= (length cancel-hook) 2))
          (should (memq original-finish finish-hook))
          (should (memq original-cancel cancel-hook))
          ;; with-editor は終了後、一時バッファで post-* hook を呼ぶ。
          (kill-buffer buffer)
          (funcall (car finish-hook))
          (should (= selected 2))
          (setq selected nil)
          (funcall (car cancel-hook))
          (should (= selected 2)))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))


(ert-deftest my/magit-display-commit-message-from-misc-keeps-restoration ()
  "Misc で編集を開始した場合は with-editor 本来の復元処理を残す。"
  (let ((buffer (generate-new-buffer " *my-git-commit-misc-test*")))
    (unwind-protect
        (cl-letf (((symbol-function 'tab-router-current-id)
                   (lambda () 'misc))
                  ((symbol-function 'tab-router--select-destination)
                   (lambda (_destination) nil))
                  ((symbol-function 'current-window-configuration)
                   (lambda (&rest _) (ert-fail "Unexpected winconf capture")))
                  ((symbol-function 'switch-to-buffer)
                   (lambda (&rest _) nil)))
          (with-current-buffer buffer
            (setq-local with-editor-previous-winconf :original-layout)
            (setq-local with-editor-post-finish-hook nil)
            (setq-local with-editor-post-cancel-hook nil))
          (my/magit-display-commit-message buffer)
          (should (eq (buffer-local-value 'with-editor-previous-winconf buffer)
                      :original-layout))
          (should-not (buffer-local-value 'with-editor-post-finish-hook buffer))
          (should-not (buffer-local-value 'with-editor-post-cancel-hook buffer)))
      (kill-buffer buffer))))


(ert-deftest my/magit-return-to-tab-skips-closed-tab ()
  "コミット編集中に元の Tab が閉じられてもエラーにならない。"
  (cl-letf (((symbol-function 'tab-router-find-tab-by-id)
             (lambda (_id) nil))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (&rest _) (ert-fail "Closed tab selected"))))
    (should-not (my/magit--return-to-tab '(project . "/work/")))))

