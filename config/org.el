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
  :hook (org-mode . org-indent-mode)
  :custom
  ;; *bold* や /italic/ の記号を通常時は隠す。
  (org-hide-emphasis-markers t)

  ;; 見出しが1段深くなるごとに2文字分インデントする。
  (org-indent-indentation-per-level 2)

  (org-tag-alist
   '(("emacs" . ?e)
     ("rag_lab" . ?r)))
  :bind
  (("C-c o c" . org-capture)
   ("C-c o a" . org-agenda)))


;; Orgの表示を見やすく整える。
;; 隠れているOrgの記号を、カーソルを置いたときだけ表示する。
(use-package org-appear
  :ensure t
  :after org
  :hook (org-mode . org-appear-mode)
  :custom
  ;; [[URL][説明]] のURL部分もカーソル位置で表示する。
  (org-appear-autolinks t))


(setq org-agenda-files
      (list org-default-notes-file))


;;; org.el ends here
