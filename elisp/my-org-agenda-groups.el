;;; my-org-agenda-groups.el --- Span-specific Agenda groups -*- lexical-binding: t; -*-
;;; Commentary:
;; 日別 Agenda は締切と行動、週別 Agenda はカテゴリでグループ化する。
;; Agenda の生成時にだけグループ設定を切り替え、d/w/g/f/b を維持する。

;;; Code:

(require 'org-agenda)

(defvar org-super-agenda-groups)
(defvar org-super-agenda-header-prefix)

;; 標準セレクタの :and で状態とカテゴリを組み合わせる。
;; カテゴリが増えたらこの一覧へ追加する。未登録カテゴリは Other に残す。
(defvar my/org-agenda-day-groups
  '((:name "Overdue / Development"
     :and (:deadline past :category "Development"))
    (:name "Overdue / Personal"
     :and (:deadline past :category "Personal"))
    (:name "Overdue / Events"
     :and (:deadline past :category "Events"))
    (:name "Due Today / Development"
     :and (:deadline today :category "Development"))
    (:name "Due Today / Personal"
     :and (:deadline today :category "Personal"))
    (:name "Due Today / Events"
     :and (:deadline today :category "Events"))
    (:name "Scheduled / Development"
     :and (:scheduled t :category "Development"))
    (:name "Scheduled / Personal"
     :and (:scheduled t :category "Personal"))
    (:name "Scheduled / Events"
     :and (:scheduled t :category "Events"))
    (:name "Other / Development" :category "Development")
    (:name "Other / Personal" :category "Personal")
    (:name "Other / Events" :category "Events")
    (:name "Other" :anything t))
  "日別 Agenda の複合グループ。先に一致した条件を優先する。")

(defun my/org-agenda-category-header (_item)
  "org-super-agenda の分類対象項目のカテゴリ名を返す。
:auto-map の呼び出し元が項目の Org バッファと見出しへ移動する。"
  (org-get-category))

(defvar my/org-agenda-week-groups
  '((:auto-map my/org-agenda-category-header))
  "週別 Agenda のグループ。Category: を付けずにカテゴリ名だけ表示する。")

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
        (let ((org-super-agenda-groups groups)
              (org-super-agenda-header-prefix "  "))
          (apply original args))
      (apply original args))))


(defun my/org-agenda-groups--effective-span (arg span)
  "Agenda 呼び出し引数 ARG・SPAN から実際の表示期間を決める。
d/w の再表示時は org-agenda-overriding-arguments を優先する。"
  (let* ((override (and org-agenda-overriding-arguments
                        (nth 2 org-agenda-overriding-arguments)))
         (raw (or override
                  (and (integerp arg) (> arg 0) arg)
                  span org-agenda-span)))
    (if (and (integerp raw) (> raw 0))
        (org-agenda-ndays-to-span raw)
      raw)))

(defun my/org-agenda-groups-around-list (original &rest args)
  "ORIGINAL で Agenda を生成し、日・週だけカテゴリの重複表示を省く。
グループ見出しにカテゴリがあるため、項目には状態と時刻だけを残す。
ほかの表示期間や TODO 一覧の書式は変更しない。"
  (let ((span (my/org-agenda-groups--effective-span
               (nth 0 args) (nth 2 args))))
    (if (memq span '(day week))
        (let ((org-agenda-prefix-format
               (cons '(agenda . "    %-13s%-12t")
                     (assq-delete-all 'agenda
                                      (copy-tree org-agenda-prefix-format)))))
          (apply original args))
      (apply original args))))

(provide 'my-org-agenda-groups)
;;; my-org-agenda-groups.el ends here
