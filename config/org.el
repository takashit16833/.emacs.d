;;; org.el --- Org configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Org に関する設定。

;;; Code:

;; Orgファイルの保存先。
(setq org-directory (expand-file-name "~/org/"))
(setq org-default-notes-file
      (expand-file-name "notes.org" org-directory))

(require 'my-org-commands)

(use-package org
  :ensure nil
  :hook ((org-mode . org-indent-mode)
         (org-mode . visual-line-mode)
	 (org-agenda-finalize . org-modern-agenda))
  :config
  ;; Orgリンク先のファイルを現在のウィンドウで開く。
  (setf (alist-get 'file org-link-frame-setup) 'find-file)

  :custom
  ;; *bold* や /italic/ の記号を通常時は隠す。
  (org-hide-emphasis-markers t)

  ;; 見出しが1段深くなるごとに2文字分インデントする。
  (org-indent-indentation-per-level 2)

  (org-tag-alist
   '(("emacs" . ?e)
     ("ai_support_desk" . ?a)))

  (org-capture-templates
   `(("i" "Inbox" entry
      (file+headline ,org-default-notes-file "Inbox")
      "* TODO %?\n  CREATED: %U"
      :empty-lines 1)))

  :bind
  (("<f13>" . my/org-capture-inbox)
   ("M-d" . my/org-home-toggle)
   ("<f14>" . org-agenda)

   :map org-mode-map
   ("s-," . my/org-insert-created)
   ("M-S-<return>" . org-insert-todo-heading-respect-content)
   ("M-s-<return>" . my/org-insert-child-task)))


;; Mermaidのソースコードだけを、Orgバッファを開いたときに折りたたむ。
;; ほかの言語のソースブロックには影響しない。
(add-hook 'org-mode-hook #'my/org-hide-mermaid-blocks)

;;; org.el ends here
