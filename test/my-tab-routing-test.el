;;; my-tab-routing-test.el --- Tests for tab routing -*- lexical-binding: t; -*-

;;; Commentary:
;; ファイルの所属と拡張子による振り分け順序を検証する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'seq)
(require 'my-tab-routing)


(ert-deftest my/tab-routing-org-directory-takes-priority ()
  "Org リポジトリ内では拡張子を問わず Org Tab を選ぶ。"
  (dolist (name '("notes.org" "README.md" "data.txt"))
    (let ((file (expand-file-name name "~/org/")))
      (should (equal (my/route-org file)
                     '(:id org :name "Org" :directory nil))))))


(ert-deftest my/tab-routing-org-directory-boundary ()
  "名前が似ている別のディレクトリは Org リポジトリではない。"
  (should-not (my/route-org (expand-file-name "~/org-backup/notes.org")))
  (should-not (my/route-org (expand-file-name "~/elsewhere/notes.org"))))


(ert-deftest my/tab-routing-documents ()
  "Org リポジトリ以外の org/md は Document Tab を選ぶ。"
  (dolist (name '("README.md" "notes.org" "NOTES.ORG" "README.MD"))
    (should (equal (my/route-document (concat "/tmp/" name))
                   '(:id document :name "Document" :directory nil))))
  (should-not (my/route-document "/tmp/main.py")))


(ert-deftest my/tab-routing-precedence ()
  "Org、Document、Project の順に最初の一致を採用する。"
  (cl-letf (((symbol-function 'project-current)
             (lambda (&rest _) '(vc Git "/tmp/sample-project/")))
            ((symbol-function 'project-root)
             (lambda (_) "/tmp/sample-project/")))
    (let ((rules '(my/route-org my/route-document my/route-project)))
      (dolist (case `((,(expand-file-name "~/org/notes.org") . org)
                      ("/tmp/sample-project/README.md" . document)
                      ("/tmp/sample-project/main.py" . project)))
        (let* ((file (car case))
               (route (seq-some (lambda (fn) (funcall fn file)) rules))
               (id (plist-get route :id)))
          (if (eq (cdr case) 'project)
              (should (equal id '(project . "/tmp/sample-project/")))
            (should (eq id (cdr case)))))))))


(provide 'my-tab-routing-test)

;;; my-tab-routing-test.el ends here
