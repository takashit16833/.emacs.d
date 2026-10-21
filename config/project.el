;;; project.el --- Project configuration -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(require 'my-project)
(require 'my-project-database)
(require 'my-tab-context)

;; vterm本体とmy-vtermは、実際に使うまで読み込まない。
(autoload 'my/vterm-toggle "my-vterm" nil t)


(use-package project
  :ensure nil

  :bind
  (("s-p" . my/project-find-file)
   :map project-prefix-map
   ("t" . my/project-run-command)
   ("b" . my/project-open-database))

  :custom
  (project-switch-commands
   '((project-find-file "Find file" ?p)
     (project-find-regexp "Find regexp" ?f)
     (my/project-run-command "Run command" ?t)
     (my/project-open-database "Database" ?b)
     (my/vterm-toggle "Vterm" ?j)
     (magit-project-status "Magit" ?m)
     (dirvish "Dirvish" ?d)
     (project-any-command "Other" ?o))))


(provide 'project-config)

;;; project.el ends here
