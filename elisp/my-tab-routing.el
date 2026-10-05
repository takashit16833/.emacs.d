;;; my-tab-routing.el --- Personal tab routing rules -*- lexical-binding: t; -*-

;;; Commentary:
;; Tab Router で使用する個人用のルーティングルールを定義する。

;;; Code:

(require 'project)


(defun my/route-org (file)
  "Org ファイル FILE を Org Tab へルーティングする。"
  (when (string-equal
         (downcase (or (file-name-extension file) ""))
         "org")
    '(:id org
      :name "Org"
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
