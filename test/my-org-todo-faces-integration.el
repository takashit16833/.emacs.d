;;; my-org-todo-faces-integration.el --- Org TODO face tests -*- lexical-binding: t; -*-

;;; Commentary:
;; org-modernのキーワード別faceが実際に適用されることを確認する。

;;; Code:

(require 'ert)
(require 'org)
(require 'org-modern)

(load-file
 (expand-file-name
  "../config/org-appearance.el"
  (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest my/org-doing-uses-separate-org-modern-face ()
  "DOINGだけが専用faceを使い、TODOは既定のfaceを使う。"
  (should (eq (cdr (assoc "DOING" org-modern-todo-faces))
              'my/org-modern-doing))
  (with-temp-buffer
    (insert "#+TODO: TODO DOING | DONE\n"
            "* TODO Not started\n"
            "* DOING In progress\n")
    (org-mode)
    (org-modern-mode 1)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward "DOING In progress")
    (let ((face (get-text-property (- (point) (length "DOING In progress"))
                                   'face)))
      (should (memq 'my/org-modern-doing
                    (if (listp face) face (list face)))))
    (goto-char (point-min))
    (search-forward "TODO Not started")
    (let ((face (get-text-property (- (point) (length "TODO Not started"))
                                   'face)))
      (should-not (memq 'my/org-modern-doing
                        (if (listp face) face (list face)))))))

;;; my-org-todo-faces-integration.el ends here
