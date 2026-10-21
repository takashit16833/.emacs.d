;;; org-agenda.el --- Org Agenda configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Org Agendaのグループ、表示形式、対象ファイルを設定する。

;;; Code:

;; Agenda の項目を予定・期限などでグループ化する。
(use-package org-super-agenda
  :ensure t
  :after org-agenda
  :config
  (require 'my-org-agenda-groups)
  ;; TODO 一覧は期限の緊急度と予定の有無で分類する。
  (setq org-super-agenda-groups my/org-agenda-todo-groups)
  ;; Agenda の表示期間が確定した後、日別・週別の分類に切り替える。
  ;; org-super-agenda の分類処理を包み、ほかの一覧は TODO 用設定を使う。
  (advice-add 'org-agenda-finalize-entries
              :around #'my/org-agenda-groups-around-finalize
              '((depth . -50)))
  ;; d/w の切り替えで Agenda を再生成するときも、カテゴリ列は表示しない。
  (advice-add 'org-agenda-list
              :around #'my/org-agenda-groups-around-list)
  (org-super-agenda-mode 1))


;; Agenda の日付は日本語ロケールで YYYY/MM/DD (曜日) と表示する。
;; system-time-locale は Emacs 全体の日時書式にも反映される。
(setq system-time-locale "ja_JP.UTF-8")
(setq org-agenda-format-date "%Y/%m/%d (%a)")

;; 複合 Agenda のブロック間は、隙間のない細い罫線で区切る。
;; 線の色は描画後に、縦分割線と同じ vertical-border face を適用する。
(setq org-agenda-block-separator ?─)

;; 時刻指定のある予定は表示したまま、時刻ごとの補助線は表示しない。
(setq org-agenda-use-time-grid nil)

;; 補助情報行にカテゴリ → 状態 → 時刻を並べ、欄の幅を確保する。
;; タイトル行には TODO・優先度・件名を表示する。
;; TODO・タグ検索など、Agenda 以外の一覧は標準の表示形式を維持する。
(setq org-agenda-prefix-format
      '((agenda . " %-15:c%-13s%-12t")
        ;; グループ見出しとの親子関係が分かるよう、TODO 項目は一段下げる。
        (todo . "    %i %-12:c")
        (tags . " %i %-12:c")
        (search . " %i %-12:c")))

;; Agenda のタグは表示したまま、org-modern のバッジ用に右端の余白を確保する。
;; ウィンドウ幅から求めるので、横幅の広い端末でもタグを右側に配置できる。
(defun my/org-agenda-set-tags-column ()
  "Agenda のタグの右端をウィンドウ端から6列内側に揃える。"
  (setq-local org-agenda-tags-column
              (- 6 (window-max-chars-per-line))))

(add-hook 'org-agenda-mode-hook #'my/org-agenda-set-tags-column)

;; 予定時刻は残し、時刻の後ろに表示される点線だけをなくす。
;; 時刻ごとの補助線は org-agenda-use-time-grid で無効化済み。
(setq org-agenda-time-grid
      '((daily today require-timed)
        (800 1000 1200 1400 1600 1800 2000)
        ""
        "----------------"))

;; 予定・期限の状態を短い英語で表示する。%d は回数または日数。
(setq org-agenda-scheduled-leaders '("SCHED " "SCHED %dx "))
(setq org-agenda-deadline-leaders '("DUE " "DUE IN %dD " "%dD OVERDUE "))

;; Agenda の1項目を、画面上で補助情報行とタイトル行に分ける。
;; 元のバッファは1項目1行のまま保ち、通常の Agenda 操作を維持する。
(autoload 'my/org-agenda-layout-setup "my-org-agenda-layout")
(autoload 'my/org-agenda-layout-finalize "my-org-agenda-layout")
(autoload 'my/org-agenda-layout-style-block-separators "my-org-agenda-layout")
(add-hook 'org-agenda-mode-hook #'my/org-agenda-layout-setup)
;; org-modern によるバッジ装飾が終わってから2行の表示を作る。
(add-hook 'org-agenda-finalize-hook #'my/org-agenda-layout-finalize t)
;; org-modern などの装飾が済んでから区切り線を縦分割線と同じ色にする。
(add-hook 'org-agenda-finalize-hook #'my/org-agenda-layout-style-block-separators t)

(setq org-agenda-files
      (list org-default-notes-file))


;;; org-agenda.el ends here
