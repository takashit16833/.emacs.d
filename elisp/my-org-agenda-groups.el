;;; my-org-agenda-groups.el --- Span-specific Agenda groups -*- lexical-binding: t; -*-
;;; Commentary:
;; 日別 Agenda は締切と行動、週別 Agenda はカテゴリでグループ化する。
;; Agenda の生成時にだけグループ設定を切り替え、d/w/g/f/b を維持する。

;;; Code:

(require 'org-agenda)

(defun my/org-agenda-section-header (title)
  "TITLE の左に縦線を付け、ウィンドウ幅まで細い横線を伸ばす。"
  (let* ((prefix (concat "│ " title " "))
         ;; 右端に1列残して、端末で意図しない折り返しを防ぐ。
         (length (max 0 (- (window-max-chars-per-line)
                           (string-width prefix) 1))))
    (concat prefix (make-string length ?─))))

(defvar org-super-agenda-groups)
(defvar org-super-agenda-header-prefix)
(defvar org-super-agenda-header-separator)

(defvar my/org-agenda-todo-groups
  '((:name "Overdue" :deadline past)
    (:name "Due Today" :deadline today)
    (:name "Upcoming" :deadline future)
    (:name "Scheduled" :scheduled t)
    (:name "Backlog" :anything t))
  "TODO 一覧のグループ。先に一致した条件を優先する。")

;; 日別では行動の優先順位を優先し、カテゴリは各項目に表示する。
;; 期限を持つタスクが SCHED にも出る場合は、最初の一致先にまとめる。
(defvar my/org-agenda-day-groups
  '((:name "Overdue" :deadline past)
    (:name "Due Today" :deadline today)
    (:name "Scheduled" :scheduled t)
    (:name "Other" :anything t))
  "日別 Agenda のグループ。先に一致した条件を優先する。")

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
日別・週別では分類条件を切り替え、すべてのグループ見出しを同じ
スタイルで表示する。"
  (let ((groups (my/org-agenda-groups-for-span org-agenda-current-span))
        ;; Org のアウトライン見出しと同じ感覚で、左に縦線を置く。
        (org-super-agenda-header-prefix "  ┃ ")
        ;; グループ同士に1行の余白を残す。
        (org-super-agenda-header-separator "\n"))
    (if groups
        (let ((org-super-agenda-groups groups))
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
  "ORIGINAL で Agenda を生成し、日・週別に項目の表示書式を調整する。
日別はカテゴリを各項目に残し、週別だけ重複するカテゴリを省く。
ほかの表示期間や TODO 一覧の書式は変更しない。"
  (let ((span (my/org-agenda-groups--effective-span
               (nth 0 args) (nth 2 args))))
    (if (memq span '(day week))
        (let ((org-agenda-overriding-header
               (or org-agenda-overriding-header ""))
              (org-agenda-prefix-format
               (cons (cons 'agenda
                           (if (eq span 'day)
                               "    %-14:c%-13s%-12t"
                             "    %-13s%-12t"))
                     (assq-delete-all 'agenda
                                      (copy-tree org-agenda-prefix-format)))))
          (apply original args))
      (apply original args))))

(provide 'my-org-agenda-groups)
;;; my-org-agenda-groups.el ends here
