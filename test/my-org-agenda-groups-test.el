;;; my-org-agenda-groups-test.el --- Org Agenda grouping tests -*- lexical-binding: t; -*-
;;; Commentary:
;; d/w と再描画で、グループ条件が正しく選択されることを確認する。

;;; Code:

(require 'ert)
(require 'org-agenda)
(require 'my-org-agenda-groups)

(ert-deftest my/org-agenda-groups-selects-day ()
  "日別は状態とカテゴリの複合条件でグループ化する。"
  (let ((groups (my/org-agenda-groups-for-span 'day)))
    (should (equal
             (car groups)
             '(:name "Overdue / Development"
               :and (:deadline past :category "Development"))))
    (should (member
             '(:name "Due Today / Personal"
               :and (:deadline today :category "Personal"))
             groups))
    (should (member
             '(:name "Scheduled / Development"
               :and (:scheduled t :category "Development"))
             groups))
    ;; 未登録カテゴリも捨てずに Other として残す。
    (should (equal (car (last groups))
                   '(:name "Other" :anything t)))))

(ert-deftest my/org-agenda-groups-selects-week ()
  "週別表示ではカテゴリ名だけを見出しにする。"
  (should (equal
           (my/org-agenda-groups-for-span 'week)
           '((:auto-map my/org-agenda-category-header)))))

(ert-deftest my/org-agenda-groups-category-header ()
  "週別カテゴリの見出しは Category: を付けない。"
  (cl-letf (((symbol-function 'org-get-category)
             (lambda (&rest _) "Development")))
    (should (equal (my/org-agenda-category-header "entry")
                   "Development"))))

(ert-deftest my/org-agenda-groups-span-from-overriding-arguments ()
  "d/w の表示切替時は再生成用の引数を優先する。"
  (let ((org-agenda-overriding-arguments '(nil 740000 day))
        (org-agenda-span 'week))
    (should (eq 'day (my/org-agenda-groups--effective-span nil nil))))
  (let ((org-agenda-overriding-arguments '(nil 740000 week))
        (org-agenda-span 'day))
    (should (eq 'week (my/org-agenda-groups--effective-span nil nil)))))

(ert-deftest my/org-agenda-groups-numeric-span ()
  "1日・7日指定はそれぞれ日別・週別とみなす。"
  (let ((org-agenda-overriding-arguments nil)
        (org-agenda-span 'month))
    (should (eq 'day (my/org-agenda-groups--effective-span 1 nil)))
    (should (eq 'week (my/org-agenda-groups--effective-span 7 nil)))))

(ert-deftest my/org-agenda-groups-compact-prefix-day-and-week ()
  "日別・週別の項目から重複カテゴリを省き、既存書式を復元する。"
  (let ((org-agenda-prefix-format
         '((agenda . "ORIGINAL") (todo . "TODO ORIGINAL")))
        (org-agenda-overriding-arguments nil)
        (org-agenda-span 'day))
    (dolist (span '(day week))
      (let ((org-agenda-span span))
        (should
         (equal
          (my/org-agenda-groups-around-list
           (lambda (&rest _args)
             (list (alist-get 'agenda org-agenda-prefix-format)
                   (alist-get 'todo org-agenda-prefix-format))))
          '("    %-13s%-12t" "TODO ORIGINAL")))))
    (should (equal (alist-get 'agenda org-agenda-prefix-format)
                   "ORIGINAL"))))

(ert-deftest my/org-agenda-groups-other-prefixes-unchanged ()
  "月間 Agenda は今までどおりカテゴリ列を残す。"
  (let ((org-agenda-prefix-format '((agenda . "ORIGINAL")))
        (org-agenda-overriding-arguments nil)
        (org-agenda-span 'month))
    (should (equal
             (my/org-agenda-groups-around-list
              (lambda (&rest _args)
                (alist-get 'agenda org-agenda-prefix-format)))
             "ORIGINAL"))))

(ert-deftest my/org-agenda-groups-other-spans-unchanged ()
  "日別・週別以外では従来の設定を変更しない。"
  (dolist (span '(nil month year fortnight 3))
    (should-not (my/org-agenda-groups-for-span span))))

(ert-deftest my/org-agenda-groups-binds-day-during-finalize ()
  "日別で生成中だけ日別グループを適用し、元の値を復元する。"
  (let ((org-agenda-current-span 'day)
        (org-super-agenda-groups '((:name "Original" :anything t))))
    (should
     (equal
      (my/org-agenda-groups-around-finalize
       (lambda (&rest args)
         (list org-super-agenda-groups args))
       '("entry") 'agenda)
      (list my/org-agenda-day-groups '(("entry") agenda))))
    (should (equal org-super-agenda-groups
                   '((:name "Original" :anything t))))))

(ert-deftest my/org-agenda-groups-binds-week-during-finalize ()
  "週表示と再生成で週別グループを適用する。"
  (let ((org-agenda-current-span 'week)
        (org-super-agenda-groups nil))
    (dotimes (_ 2)
      (should
       (equal (my/org-agenda-groups-around-finalize
               (lambda (&rest _args) org-super-agenda-groups)
               '("entry") 'agenda)
              my/org-agenda-week-groups)))
    (should-not org-super-agenda-groups)))

(ert-deftest my/org-agenda-groups-preserves-non-agenda-groups ()
  "TODO 一覧などは元のグループ設定を使用する。"
  (let ((org-agenda-current-span nil)
        (org-super-agenda-groups '((:name "Original" :anything t))))
    (should
     (equal (my/org-agenda-groups-around-finalize
             (lambda (&rest _args) org-super-agenda-groups))
            org-super-agenda-groups))))

(ert-deftest my/org-agenda-groups-restore-after-error ()
  "分類中にエラーが発生しても設定が漏れない。"
  (let ((org-agenda-current-span 'day)
        (org-super-agenda-groups '((:name "Original" :anything t))))
    (should-error
     (my/org-agenda-groups-around-finalize
      (lambda (&rest _args) (error "test error"))))
    (should (equal org-super-agenda-groups
                   '((:name "Original" :anything t))))))


(ert-deftest my/org-agenda-groups-indents-group-headers ()
  "グループの見出しは2列インデントする。"
  (let ((org-agenda-current-span 'week)
        (org-super-agenda-header-prefix " "))
    (should
     (equal
      (my/org-agenda-groups-around-finalize
       (lambda (&rest _args) org-super-agenda-header-prefix))
      "  "))
    (should (equal org-super-agenda-header-prefix " "))))

;;; my-org-agenda-groups-test.el ends here
