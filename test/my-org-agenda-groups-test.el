;;; my-org-agenda-groups-test.el --- Org Agenda grouping tests -*- lexical-binding: t; -*-
;;; Commentary:
;; d/w と再描画で、グループ条件が正しく選択されることを確認する。

;;; Code:

(require 'ert)
(require 'org-agenda)
(require 'my-org-agenda-groups)

;; org-super-agenda を直接ロードせずにテストするため、
;; 設定変数を動的に束縛できるよう宣言しておく。
(defvar org-super-agenda-groups)
(defvar org-super-agenda-header-prefix)
(defvar org-super-agenda-header-separator)

(ert-deftest my/org-agenda-groups-todo-groups-by-state ()
  "TODO 一覧は期限の緊急度と予定状態の順に分類する。"
  (should
   (equal
    (mapcar (lambda (group)
              (list (substring-no-properties (plist-get group :name))
                    (plist-get group :deadline)
                    (plist-get group :scheduled)
                    (plist-get group :anything)))
            my/org-agenda-todo-groups)
    '(("Overdue" past nil nil)
      ("Due Today" today nil nil)
      ("Upcoming" future nil nil)
      ("Scheduled" nil t nil)
      ("Backlog" nil nil t)))))

(ert-deftest my/org-agenda-groups-todo-group-header-faces ()
  "TODO グループ名には状態別の見出し face を付ける。"
  (dolist (case
           '(("Overdue" . my/org-agenda-group-overdue)
             ("Due Today" . my/org-agenda-group-due-today)
             ("Upcoming" . my/org-agenda-group-upcoming)
             ("Scheduled" . my/org-agenda-group-scheduled)
             ("Backlog" . my/org-agenda-group-backlog)))
    (let* ((group
            (cl-find-if
             (lambda (candidate)
               (equal (substring-no-properties (plist-get candidate :name))
                      (car case)))
             my/org-agenda-todo-groups))
           (name (plist-get group :name)))
      (should group)
      (should (eq (get-text-property 0 'face name) (cdr case))))))

(ert-deftest my/org-agenda-groups-selects-day ()
  "日別では4つの行動・期限グループへ分類する。"
  (should
   (equal (my/org-agenda-groups-for-span 'day)
          '((:name "Overdue" :deadline past)
            (:name "Due Today" :deadline today)
            (:name "Scheduled" :scheduled t)
            (:name "Other" :anything t)))))

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
  "日別だけカテゴリを残し、週別では省略する。"
  (let ((org-agenda-prefix-format
         '((agenda . "ORIGINAL") (todo . "TODO ORIGINAL")))
        (org-agenda-overriding-arguments nil))
    (dolist (case '((day . "    %-14:c%-13s%-12t")
                    (week . "    %-13s%-12t")))
      (let ((org-agenda-span (car case)))
        (should
         (equal
          (my/org-agenda-groups-around-list
           (lambda (&rest _args)
             (list (alist-get 'agenda org-agenda-prefix-format)
                   (alist-get 'todo org-agenda-prefix-format))))
          (list (cdr case) "TODO ORIGINAL")))))
    (should (equal (alist-get 'agenda org-agenda-prefix-format)
                   "ORIGINAL"))))

(ert-deftest my/org-agenda-groups-hides-day-and-week-header ()
  "日別・週別では上部の Agenda 見出しだけを非表示にする。"
  (let ((org-agenda-overriding-arguments nil)
        (org-agenda-overriding-header "Original"))
    (dolist (span '(day week))
      (let ((org-agenda-span span))
        (should
         (equal
          (my/org-agenda-groups-around-list
           (lambda (&rest _args) org-agenda-overriding-header))
          ""))))
    (should (equal org-agenda-overriding-header "Original"))))

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

(ert-deftest my/org-agenda-groups-styles-todo-headers ()
  "TODO 一覧でも日・週 Agenda と同じグループ見出しを使う。"
  (let ((org-agenda-current-span nil)
        (org-super-agenda-header-prefix "ORIGINAL")
        (org-super-agenda-header-separator "ORIGINAL"))
    (should
     (equal
      (my/org-agenda-groups-around-finalize
       (lambda (&rest _args)
         (list org-super-agenda-header-prefix
               org-super-agenda-header-separator)))
      '("  ┃ " "\n")))
    (should (equal org-super-agenda-header-prefix "ORIGINAL"))
    (should (equal org-super-agenda-header-separator "ORIGINAL"))))

(ert-deftest my/org-agenda-groups-restore-after-error ()
  "分類中にエラーが発生しても設定が漏れない。"
  (let ((org-agenda-current-span 'day)
        (org-super-agenda-groups '((:name "Original" :anything t))))
    (should-error
     (my/org-agenda-groups-around-finalize
      (lambda (&rest _args) (error "test error"))))
    (should (equal org-super-agenda-groups
                   '((:name "Original" :anything t))))))


(ert-deftest my/org-agenda-groups-styles-group-headers ()
  "グループ見出しは2列下げ、Org 見出しと同じ左線を付ける。"
  (let ((org-agenda-current-span 'week)
        (org-super-agenda-header-prefix " "))
    (should
     (equal
      (my/org-agenda-groups-around-finalize
       (lambda (&rest _args) org-super-agenda-header-prefix))
      "  ┃ "))
    (should (equal org-super-agenda-header-prefix " "))))

(ert-deftest my/org-agenda-groups-week-retains-header-gap ()
  "週別でも日付とカテゴリ、カテゴリ間の余白を残す。"
  (let ((org-agenda-current-span 'week)
        (org-super-agenda-header-separator "CUSTOM"))
    (should
     (equal
      (my/org-agenda-groups-around-finalize
       (lambda (&rest _args) org-super-agenda-header-separator))
      "\n"))
    (should (equal org-super-agenda-header-separator "CUSTOM"))))

(ert-deftest my/org-agenda-groups-day-retains-header-gap ()
  "日別ではグループ見出し間の余白を残す。"
  (let ((org-agenda-current-span 'day)
        (org-super-agenda-header-separator "CUSTOM"))
    (should
     (equal
      (my/org-agenda-groups-around-finalize
       (lambda (&rest _args) org-super-agenda-header-separator))
      "\n"))
    (should (equal org-super-agenda-header-separator "CUSTOM"))))

;;; my-org-agenda-groups-test.el ends here
