;;; my-tab-routing.el --- Personal tab routing rules -*- lexical-binding: t; -*-

;;; Commentary:
;; 優先順: ~/org/ 配下 -> 文書ファイル -> 各プロジェクト。
;; Tab Router は最初に non-nil を返したルールを採用する。

;;; Code:

(require 'project)


(defun my/route-org (file)
  "FILE が ~/org/ 配下なら Org Tab へルーティングする。"
  (when (string-prefix-p
         (file-name-as-directory (expand-file-name "~/org"))
         (expand-file-name file))
    '(:id org
      :name "Org"
      :directory nil)))


(defun my/route-document (file)
  "Org / Markdown ファイル FILE を Document Tab へルーティングする。"
  (when (member (downcase (or (file-name-extension file) ""))
                '("org" "md"))
    '(:id document
      :name "Document"
      :directory nil)))


(defun my/route-project (file)
  "FILE が属する Project の Tab へルーティングする。"
  (when-let* ((project
               (project-current nil
                                (file-name-directory file)))
              (root
               (file-name-as-directory
                (expand-file-name
                 (project-root project)))))
    `(:id (project . ,root)
      :name ,(file-name-nondirectory
              (directory-file-name root))
      :directory ,root)))


(provide 'my-tab-routing)

;;; my-tab-routing.el ends here
