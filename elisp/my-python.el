;;; my-python.el --- Python development helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Pythonプロジェクトで使用する外部コマンドを解決する。

;;; Code:

(require 'project)


;; Pythonはプロジェクト内のBasedpyrightを優先する。
;; 存在しなければPATH上のBasedpyrightを使用する。
(defun my/eglot-python-server (_interactive)
  "Python用Language Serverの起動コマンドを返す。"
  (let* ((project (project-current nil))
         (local-server
          (when project
            (expand-file-name
             ".venv/bin/basedpyright-langserver"
             (project-root project))))
         (server
          (if (and local-server
                   (file-executable-p local-server))
              local-server
            (executable-find "basedpyright-langserver"))))
    (unless server
      (user-error "Python用Basedpyrightが見つかりません"))
    (list server "--stdio")))


(provide 'my-python)

;;; my-python.el ends here

