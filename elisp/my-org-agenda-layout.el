;;; my-org-agenda-layout.el --- Two-line Org Agenda display -*- lexical-binding: t; -*-

;;; Commentary:
;; Agenda の1項目を1行のまま保持し、画面上では補助情報とタイトルを分ける。
;; 項目は overlay で装飾し、日付行の改行には face を追加する。

;;; Code:

(require 'org-agenda)
(require 'subr-x)

(defun my/org-agenda-layout--tags (raw)
  "Org のタグ文字列 RAW をテーマに沿ったラベルにする。"
  (let ((face (if (facep 'org-modern-tag) 'org-modern-tag 'org-tag)))
    (mapconcat (lambda (tag)
                 (propertize (concat " " tag " ") 'face face))
               (split-string raw ":" t)
               " ")))

(defun my/org-agenda-layout--metadata (prefix raw-tags width)
  "PREFIX と RAW-TAGS から、幅 WIDTH の補助情報行を作る。
戻り値の末尾には改行と6列のタイトル行インデントを付ける。"
  (let* ((prefix (string-trim-right prefix))
         (tags (my/org-agenda-layout--tags (or raw-tags "")))
         (spaces (if (string-empty-p tags)
                     ""
                   (make-string
                    (max 2 (- width 6
                              (string-width prefix)
                              (string-width tags)))
                    ?\s))))
    (concat prefix spaces tags "\n      ")))

(defun my/org-agenda-set-tags-column ()
  "Agenda のタグの右端をウィンドウ端から6列内側に揃える。"
  (setq-local org-agenda-tags-column
              (- 6 (window-max-chars-per-line))))

(defun my/org-agenda-layout-setup ()
  "Agenda の長いタイトルを端末幅に合わせて折り返す。"
  (setq-local truncate-lines nil)
  (setq-local word-wrap t))

(defun my/org-agenda-layout--title-start (beg end)
  "Agenda 項目の BEG と END の間でタイトルの開始位置を返す。
Org は TODO を整形する際に見出し属性を失う場合があるので、
残った見出し属性の前に TODO があれば、その開始位置まで戻す。"
  (let ((heading (text-property-any beg end 'org-heading t))
        (re (get-text-property beg 'org-todo-regexp)))
    (when (and heading re)
      (save-excursion
        (goto-char beg)
        (when (re-search-forward
               (concat "[[:space:]]\\(" re "\\)[[:space:]]+")
               heading t)
          (setq heading (match-beginning 1)))))
    heading))

(defun my/org-agenda-layout--extend-date-background ()
  "Agenda の日付行の背景を、行末まで表示する。
日付に既に設定された face を改行文字にも適用し、face の
:extend 属性を使う。文字列や他の行の装飾は変更しない。"
  (save-excursion
    (goto-char (point-min))
    (while (< (point) (point-max))
      (let ((beg (line-beginning-position))
            (end (line-end-position)))
        (when (and (< end (point-max))
                   (get-text-property beg 'org-agenda-date-header))
          (when-let* ((face (get-text-property beg 'face)))
            (let ((inhibit-read-only t))
              (put-text-property end (1+ end) 'face face)))))
      (forward-line 1))))

(defun my/org-agenda-layout-finalize ()
  "日付付き Agenda の各項目を表示上だけ2行にする。
元のテキストとその Org マーカーは変更しないので、Agenda の
行単位の操作を維持できるようにする。"
  (when (and (derived-mode-p 'org-agenda-mode)
             org-agenda-current-span)
    ;; Agenda の再生成や再実行後も装飾が重複しないようにする。
    (remove-overlays (point-min) (point-max)
                     'my/org-agenda-layout t)
    ;; 日付の face を改行にも付け、テーマ側の :extend を有効にする。
    (my/org-agenda-layout--extend-date-background)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let* ((beg (line-beginning-position))
               (end (line-end-position))
               (heading (my/org-agenda-layout--title-start beg end)))
          (when (and heading
                     (> heading beg)
                     (get-text-property heading 'org-marker))
            (let ((prefix (buffer-substring beg heading))
                  (tag-beg nil)
                  (raw-tags nil))
              ;; Agenda 右端のタグを補助情報行へ移す。
              (goto-char heading)
              (when (re-search-forward org-tag-group-re end t)
                (setq tag-beg (match-beginning 0)
                      raw-tags (match-string-no-properties 1)))
              (let ((ov (make-overlay beg heading)))
                (overlay-put ov 'my/org-agenda-layout t)
                (overlay-put ov 'before-string
                             (my/org-agenda-layout--metadata
                              prefix raw-tags (window-max-chars-per-line)))
                (overlay-put ov 'display ""))
              (when tag-beg
                (let ((ov (make-overlay tag-beg end)))
                  (overlay-put ov 'my/org-agenda-layout t)
                  (overlay-put ov 'display "")))))
          (goto-char end)
          (forward-line 1))))))

(defun my/org-agenda-layout-style-block-separators ()
  "複合 Agenda の横罫線に、縦分割線と同じ face を適用する。
元の文字列は変更せず、テーマ切り替え後も同じ色を参照する。"
  (when (derived-mode-p 'org-agenda-mode)
    (save-excursion
      (goto-char (point-min))
      (let ((inhibit-read-only t))
        (while (re-search-forward "^─+$" nil t)
          (put-text-property (match-beginning 0) (match-end 0)
                             'face 'vertical-border))))))

(provide 'my-org-agenda-layout)
;;; my-org-agenda-layout.el ends here
