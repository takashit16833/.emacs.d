;;; my-org-agenda-groups-test.el --- Org Agenda grouping tests -*- lexical-binding: t; -*-
;;; Commentary:
;; d/w と再描画で、グループ条件が正しく選択されることを確認する。

;;; Code:

(require 'ert)
(require 'org-agenda)
(require 'my-org-agenda-groups)

(ert-deftest my/org-agenda-groups-selects-day ()
  "日別表示では締切と作業予定を基準にグループ化する。"
  (should (equal
           (my/org-agenda-groups-for-span 'day)
           '((:name "Overdue" :deadline past)
             (:name "Due Today" :deadline today)
             (:name "Scheduled" :scheduled t)
             (:name "Other" :anything t)))))

(ert-deftest my/org-agenda-groups-selects-week ()
  "週別表示ではカテゴリごとにグループ化する。"
  (should (equal
           (my/org-agenda-groups-for-span 'week)
           '((:auto-category t)))))

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

;;; my-org-agenda-groups-test.el ends here
