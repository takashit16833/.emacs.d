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


(defun my/dirvish--git-ignored-paths (directory files)
  "DIRECTORYを基準にGitで無視されるFILESの絶対パスを返す。
判定に失敗した場合はnil、成功した場合は(t . PATHS)を返す。"
  (with-temp-buffer
    ;; Gitは -C に渡された "~" を展開しないので絶対パスへ統一する。
    (dolist (file files)
      (insert (expand-file-name file) "\0"))
    (let ((status
           (call-process-region
            (point-min) (point-max) "git" t t nil
            "-C" (expand-file-name directory)
            "check-ignore" "-z" "--stdin")))
      (if (memq status '(0 1))
          (cons t (split-string (buffer-string) "\0" t))
        (message "Dirvish: git check-ignore failed (%s): %s"
                 status (string-trim (buffer-string)))
        nil))))


(defun my/dirvish-dim-ignored (&rest _args)
  "Dirvishの展開済みツリーを含めignoredファイル名を暗くする。"
  (when (and (fboundp 'dirvish-curr)
             (dirvish-curr)
             (not (file-remote-p default-directory))
             (executable-find "git"))
    (let ((root (expand-file-name default-directory))
          entries)
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when-let* ((beg (dired-move-to-filename))
                      (end (dired-move-to-end-of-filename t))
                      (file (dired-get-filename nil t)))
            (push (list (expand-file-name file) beg end) entries))
          (forward-line 1)))
      (when entries
        (when-let* ((result
                     (my/dirvish--git-ignored-paths
                      root (mapcar #'car entries))))
          (let ((ignored (make-hash-table :test #'equal))
                (color (face-attribute
                        'tab-bar-tab-inactive :foreground nil t)))
            (dolist (file (cdr result))
              (puthash file t ignored))
            (remove-overlays (point-min) (point-max)
                             'my/dirvish-ignored t)
            (dolist (entry entries)
              (pcase-let ((`(,file ,beg ,end) entry))
                (when (gethash file ignored)
                  (let ((ov (make-overlay beg end)))
                    (overlay-put ov 'my/dirvish-ignored t)
                    (overlay-put ov 'face
                                 `(:foreground ,color))))))))))))

(provide 'my-files)


;;; my-files.el ends here
