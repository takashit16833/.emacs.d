;;; org.el --- Org configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Org に関する設定。

;;; Code:

;; Orgファイルの保存先。
(setq org-directory (expand-file-name "~/org/"))
(setq org-default-notes-file
      (expand-file-name "notes.org" org-directory))


(use-package org
  :ensure nil
  :custom
  (org-tag-alist
   '(("emacs" . ?e)
     ("rag_lab" . ?r)))
  :bind
  (("C-c o c" . org-capture)
   ("C-c o a" . org-agenda)))


(setq org-agenda-files
      (list org-default-notes-file))


;;; org.el ends here
