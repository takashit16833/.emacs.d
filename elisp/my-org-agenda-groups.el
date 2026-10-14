;;; my-org-agenda-groups.el --- Span-specific Agenda groups -*- lexical-binding: t; -*-
;;; Commentary:
;; 日別 Agenda は締切と行動、週別 Agenda はカテゴリでグループ化する。
;; Agenda の生成時にだけグループ設定を切り替え、d/w/g/f/b を維持する。

;;; Code:

(require 'org-agenda)

(defvar org-super-agenda-groups)

(defvar my/org-agenda-day-groups
  '((:name "Overdue" :deadline past)
    (:name "Due Today" :deadline today)
    (:name "Scheduled" :scheduled t)
    (:name "Other" :anything t))
  "日別 Agenda のグループ。先に一致したグループが優先される。")

(defvar my/org-agenda-week-groups
  '((:auto-category t))
  "週別 Agenda のグループ。カテゴリ名をグループ見出しにする。")

(defun my/org-agenda-groups-for-span (span)
  "Agenda の表示期間 SPAN に対応するグループを返す。
日別と週別以外では nil を返し、既存のグループ設定を維持する。"
  (pcase span
    ('day my/org-agenda-day-groups)
    ('week my/org-agenda-week-groups)))

(defun my/org-agenda-groups-around-finalize (original &rest args)
  "ORIGINAL を ARGS で呼び、Agenda の表示期間に応じてグループ化する。
org-agenda-finalize-entries の呼び出し時には表示期間が確定している。
その処理中だけ org-super-agenda-groups を動的に束縛する。"
  (let ((groups (my/org-agenda-groups-for-span org-agenda-current-span)))
    (if groups
        (let ((org-super-agenda-groups groups))
          (apply original args))
      (apply original args))))

(provide 'my-org-agenda-groups)
;;; my-org-agenda-groups.el ends here
