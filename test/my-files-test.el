;;; my-files-test.el --- Tests for my-files -*- lexical-binding: t; -*-

;;; Commentary:
;; Dirvishプレビューの配置と、Git ignoredのファイル名装飾を確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-files)

;; -QのテストでもDirvish本体を読み込まず関数をモックできるようにする。
(autoload 'dirvish-curr "dirvish")


(ert-deftest my/dirvish-preview-below-uses-layout-preview-ratio ()
  "レイアウトのプレビュー幅を下側プレビューの高さとして使う。"
  (let ((buffer (get-buffer-create "*dirvish-preview@test*"))
        (args '((side . right) (window-width . 0.6)))
        received)
    (unwind-protect
        (cl-letf (((symbol-function 'window-total-height)
                   (lambda (&rest _) 100)))
          (my/dirvish-preview-below
           (lambda (_buffer alist)
             (setq received alist))
           buffer args)
          (should (eq (alist-get 'side received) 'below))
          (should (= (alist-get 'window-height received) -60))
          ;; 呼び出し元の引数は変更しない。
          (should (eq (alist-get 'side args) 'right)))
      (kill-buffer buffer))))


(ert-deftest my/dirvish-preview-below-keeps-other-windows ()
  "プレビュー以外のDirvishウィンドウ配置は変更しない。"
  (let ((buffer (get-buffer-create " *dirvish-header@test*"))
        (args '((side . above) (window-height . -2)))
        received)
    (unwind-protect
        (progn
          (my/dirvish-preview-below
           (lambda (_buffer alist)
             (setq received alist))
           buffer args)
          (should (equal received args)))
      (kill-buffer buffer))))


(ert-deftest my/dirvish-git-ignored-normalizes-tilde-paths ()
  "Gitへ渡す-C引数とファイル名は絶対パスに正規化する。"
  (let* ((root "~/.emacs.d/")
         (file "~/.emacs.d/history")
         args input)
    (cl-letf (((symbol-function 'call-process-region)
               (lambda (beg end command delete destination display &rest arguments)
                 (setq args (list command delete destination display arguments)
                       input (buffer-substring-no-properties beg end))
                 (erase-buffer)
                 (insert (expand-file-name file) "\0")
                 0)))
      (should
       (equal (my/dirvish--git-ignored-paths root (list file))
              (cons t (list (expand-file-name file)))))
      (should (equal input (concat (expand-file-name file) "\0")))
      (should (equal args
                     (list "git" t t nil
                           (list "-C" (expand-file-name root)
                                 "check-ignore" "-z" "--stdin")))))))


(ert-deftest my/dirvish-git-ignored-finds-nested-files ()
  "Git ignoredディレクトリ自身とその配下のファイルを判定する。"
  (skip-unless (executable-find "git"))
  (let* ((root (make-temp-file "my-dirvish-git-" t))
         (ignored-dir (expand-file-name ".cache" root))
         (nested-file (expand-file-name ".cache/nested/data.txt" root))
         (ignored-file (expand-file-name "history" root))
         (regular-file (expand-file-name "README.md" root)))
    (unwind-protect
        (progn
          (should (= 0 (call-process "git" nil nil nil
                                     "-C" root "init" "-q")))
          (with-temp-file (expand-file-name ".gitignore" root)
            (insert ".cache/\nhistory\n"))
          (make-directory (file-name-directory nested-file) t)
          (dolist (file (list nested-file ignored-file regular-file))
            (with-temp-file file (insert "test")))
          (let ((result (my/dirvish--git-ignored-paths
                         root (list ignored-dir nested-file
                                    ignored-file regular-file))))
            (should (eq (car result) t))
            (should (member ignored-dir (cdr result)))
            (should (member nested-file (cdr result)))
            (should (member ignored-file (cdr result)))
            (should-not (member regular-file (cdr result)))))
      (delete-directory root t))))


(ert-deftest my/dirvish-dim-ignored-colors-file-name ()
  "文字色の変更は ignoredファイル名部分に限定する。"
  (skip-unless (executable-find "git"))
  (let* ((root (file-truename (make-temp-file "my-dirvish-dim-" t)))
         (ignored-file (expand-file-name "history" root))
         (ordinary-file (expand-file-name "README.md" root))
         (buf nil))
    (unwind-protect
        (progn
          (should (= 0 (call-process "git" nil nil nil
                                     "-C" root "init" "-q")))
          (with-temp-file (expand-file-name ".gitignore" root)
            (insert "history\n"))
          (with-temp-file ignored-file (insert "ignored"))
          (with-temp-file ordinary-file (insert "regular"))
          ;; 「..」が表示されるDired一覧でもGit判定が失敗しないこと。
          (let ((dired-listing-switches "-al"))
            (setq buf (dired-noselect root)))
          (with-current-buffer buf
            ;; テスト時にDirvishセッションがある状態を模擬する。
            (cl-letf (((symbol-function 'dirvish-curr) (lambda () t)))
              (my/dirvish-dim-ignored))
            (should (dired-goto-file ignored-file))
            (dired-move-to-filename)
            (should (cl-some (lambda (ov)
                               (overlay-get ov 'my/dirvish-ignored))
                             (overlays-at (point))))
            (should (dired-goto-file ordinary-file))
            (dired-move-to-filename)
            (should-not (cl-some (lambda (ov)
                                   (overlay-get ov 'my/dirvish-ignored))
                                 (overlays-at (point))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-directory root t))))


;;; my-files-test.el ends here
