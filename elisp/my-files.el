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


(provide 'my-files)


;;; my-files.el ends here
