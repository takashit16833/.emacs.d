;;; my-files.el --- File manager helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Dirvishなど、ファイル管理UIの補助処理をまとめる。

;;; Code:

(defvar project-files-relative-names)
(declare-function dired-get-filename "dired" (&optional localp no-error-if-not-filep))
(declare-function dired-find-file "dired" ())
(declare-function dirvish-subtree--expanded-p "dirvish-subtree")
(declare-function dirvish-subtree-expand-to "dirvish-subtree" (target))
(declare-function dirvish-subtree-toggle "dirvish-subtree")
(declare-function dirvish-subtree-remove "dirvish-subtree")
(declare-function project-files "project" (project &optional dirs))
(declare-function dirvish-curr "dirvish" ())
(declare-function dired-move-to-filename "dired" (&optional raise-error eol))
(declare-function dired-move-to-end-of-filename "dired" (&optional no-error))


(defun my/dirvish-collapse ()
  "現在のディレクトリ、または親のツリーを閉じる。"
  (interactive)
  (require 'dirvish-subtree)
  (if (dirvish-subtree--expanded-p)
      (dirvish-subtree-toggle)
    (dirvish-subtree-remove)))


(defun my/dirvish-expand-or-open ()
  "ディレクトリは展開し、ファイルは開く。"
  (interactive)
  (require 'dirvish-subtree)
  (when-let* ((file (dired-get-filename nil t)))
    (if (file-directory-p file)
        (unless (dirvish-subtree--expanded-p)
          (dirvish-subtree-toggle))
      (dired-find-file))))


(defun my/dirvish-project-candidates (project root)
  "PROJECT内のファイルと親ディレクトリを列挙する。"
  (let ((project-files-relative-names t)
        (seen (make-hash-table :test #'equal))
        candidates)
    (dolist (file (project-files project (list root)))
      (let ((path (file-relative-name
                   (expand-file-name file root) root)))
        (unless (or (equal path "..")
                    (string-prefix-p "../" path))
          (puthash path t seen)
          (let ((parent (file-name-directory path)))
            (while parent
              (puthash parent t seen)
              (setq parent
                    (file-name-directory
                     (directory-file-name parent))))))))
    (maphash (lambda (path _)
               (push path candidates))
             seen)
    candidates))


(defun my/dirvish-find-in-tree ()
  "Orderless補完で検索し、Dirvishのツリーを展開する。"
  (interactive)
  (require 'project)
  (require 'dirvish-subtree)
  (unless (derived-mode-p 'dired-mode)
    (user-error "Dirvishで実行してください"))
  (let* ((root (file-name-as-directory
                (expand-file-name default-directory)))
         (project (project-current nil root)))
    (unless project
      (user-error "プロジェクトが見つかりません"))
    (let* ((candidates
            (my/dirvish-project-candidates project root))
           (selected
            (completing-read "Find in tree: "
                             candidates nil t)))
      (unless (string-empty-p selected)
        (let ((target
               (directory-file-name
                (expand-file-name selected root))))
          (goto-char (point-min))
          (unless (dirvish-subtree-expand-to target)
            (user-error "ツリー内に見つかりません: %s"
                        selected)))))))


(defun my/dirvish-preview-below (original buffer alist)
  "Dirvishのプレビューを右ではなく下に表示する。
ORIGINAL, BUFFER, ALIST は `dirvish--display-buffer' の引数。
ALIST の `window-width' は、下側プレビューの高さの割合として使う。"
  (if (and (buffer-live-p buffer)
           (string-prefix-p "*dirvish-preview@" (buffer-name buffer))
           (eq (alist-get 'side alist) 'right))
      (let* ((ratio (alist-get 'window-width alist))
             (height (max 4
                          (floor (* (window-total-height) ratio))))
             (args (copy-tree alist)))
        (setf (alist-get 'side args) 'below
              (alist-get 'window-height args) (- height))
        (funcall original buffer args))
    (funcall original buffer alist)))


(defun my/dirvish-dim-ignored (&rest _args)
  "Dirvish内のGit ignoredファイル名を暗く表示する。"
  (when (and (fboundp 'dirvish-curr)
             (dirvish-curr)
             (not (file-remote-p default-directory))
             (executable-find "git"))
    (let ((root default-directory)
          (entries nil)
          (ignored (make-hash-table :test #'equal))
          (color (face-attribute
                  'tab-bar-tab-inactive :foreground nil t)))

      ;; 前回適用した装飾だけを削除する。
      (remove-overlays (point-min) (point-max)
                       'my/dirvish-ignored t)

      ;; 展開済みサブツリーを含め、表示中のファイルを収集する。
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when-let* ((beg (dired-move-to-filename))
                      (end (dired-move-to-end-of-filename t))
                      (file (dired-get-filename nil t)))
            (push (list file beg end) entries))
          (forward-line 1)))

      (when entries
        ;; Gitへの問い合わせは全ファイルまとめて1回だけ。
        (with-temp-buffer
          (dolist (entry entries)
            (insert (car entry) "\0"))

          (let ((status
                 (call-process-region
                  (point-min) (point-max)
                  "git" t t nil
                  "-C" root "check-ignore" "-z" "--stdin")))
            (when (memq status '(0 1))
              (goto-char (point-min))
              (let ((start (point)))
                (while (search-forward "\0" nil t)
                  (puthash
                   (buffer-substring-no-properties
                    start (1- (point)))
                   t ignored)
                  (setq start (point)))))))

        ;; ignoredのファイル名部分だけにfaceを適用する。
        (dolist (entry entries)
          (pcase-let ((`(,file ,beg ,end) entry))
            (when (gethash file ignored)
              (let ((ov (make-overlay beg end)))
                (overlay-put ov 'my/dirvish-ignored t)
                (overlay-put ov 'face
                             `(:foreground ,color))))))))))


(provide 'my-files)


;;; my-files.el ends here
