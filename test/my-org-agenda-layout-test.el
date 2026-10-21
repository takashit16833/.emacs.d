;;; my-org-agenda-layout-test.el --- Two-line Agenda tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Agenda の表示変更で原文や項目マーカーが失われないことを確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org-agenda)
(require 'my-org-agenda-layout)

(defun my/org-agenda-layout-test--render (line heading)
  "LINE の HEADING から始まる項目を2行表示し、buffer を返す。
テストでは返したバッファを呼び出し元で破棄する。"
  (let ((buffer (generate-new-buffer " *agenda-layout-test*")))
    (with-current-buffer buffer
      (insert line "\n")
      (setq-local major-mode 'org-agenda-mode)
      (setq-local org-agenda-current-span 'week)
      (goto-char (point-min))
      (search-forward heading)
      (let ((start (- (point) (length heading))))
        (put-text-property start (line-end-position) 'org-heading t)
        (put-text-property (point-min) (line-end-position)
                           'org-marker (copy-marker start))))
    buffer))

(ert-deftest my/org-agenda-layout-metadata-with-tags ()
  "補助情報の末尾にタグを置き、タイトル行を次の表示行にする。"
  (let* ((text (my/org-agenda-layout--metadata
                " Development:  SCHED     09:00   " ":emacs:rag_lab:" 100))
         (plain (substring-no-properties text)))
    (should (string-prefix-p " Development:  SCHED" plain))
    (should (string-match-p "emacs.*rag_lab" plain))
    (should (string-suffix-p "\n      " plain))
    (should (eq (if (facep 'org-modern-tag) 'org-modern-tag 'org-tag)
                (get-text-property (string-match "emacs" text) 'face text)))))

(ert-deftest my/org-agenda-layout-preserves-todo-and-priority ()
  "Org が TODO の見出し属性を置換してもバッジは2行目に残す。"
  (let ((buffer (my/org-agenda-layout-test--render
                 " Development:  SCHED       09:00      TODO [#B] テスト"
                 "[#B]")))
    (unwind-protect
        (with-current-buffer buffer
          (put-text-property (point-min) (line-end-position)
                             'org-todo-regexp "\\(?:TODO\\|DONE\\)")
          (my/org-agenda-layout-finalize)
          (let ((meta (cl-find-if
                       (lambda (ov) (overlay-get ov 'before-string))
                       (overlays-in (point-min) (point-max)))))
            (should meta)
            (should (eq ?T (char-after (overlay-end meta))))
            (should (string-match-p "TODO \\[#B\\]" (buffer-string)))))
      (kill-buffer buffer))))

(ert-deftest my/org-agenda-layout-preserves-original-line ()
  "装飾しても項目が物理的には1行で、元の文字列も変わらない。"
  (let* ((line " Development:  SCHED       09:00      TODO [#B] Python のテスト  :emacs:rag_lab:")
         (buffer (my/org-agenda-layout-test--render line "TODO")))
    (unwind-protect
        (with-current-buffer buffer
          (let ((original (buffer-string)))
            (my/org-agenda-layout-finalize)
            (should (equal original (buffer-string)))
            (should (= 1 (count-lines (point-min) (point-max))))
            (let* ((ovs (overlays-in (point-min) (point-max)))
                   (metadata (cl-find-if
                              (lambda (ov) (overlay-get ov 'before-string))
                              ovs))
                   (hidden-tag (cl-find-if
                                (lambda (ov)
                                  (and (/= (overlay-start ov) (point-min))
                                       (equal (overlay-get ov 'display) "")))
                                ovs)))
              (should metadata)
              (should hidden-tag)
              (should (string-match-p
                       "rag_lab"
                       (overlay-get metadata 'before-string)))
              (should (equal (overlay-get metadata 'display) "")))
            (my/org-agenda-layout-finalize)
            (should (= 2 (length (overlays-in (point-min) (point-max)))))))
      (kill-buffer buffer))))

(ert-deftest my/org-agenda-layout-without-todo ()
  "TODO のない予定も同じ位置からタイトルを表示する。"
  (let ((buffer (my/org-agenda-layout-test--render
                 " Events:                      10:00-11:00 チームミーティング"
                 "チームミーティング")))
    (unwind-protect
        (with-current-buffer buffer
          (my/org-agenda-layout-finalize)
          (let ((ovs (overlays-in (point-min) (point-max))))
            (should (= 1 (length ovs)))
            (should (string-suffix-p
                     "\n      "
                     (overlay-get (car ovs) 'before-string)))))
      (kill-buffer buffer))))

(ert-deftest my/org-agenda-layout-skips-date-heading ()
  "日付見出しや Agenda 以外の一覧は変更しない。"
  (with-temp-buffer
    (insert "2026/10/14 (水)\n")
    (setq-local major-mode 'org-agenda-mode)
    (setq-local org-agenda-current-span 'week)
    (my/org-agenda-layout-finalize)
    (should-not (overlays-in (point-min) (point-max)))
    (setq-local org-agenda-current-span nil)
    (my/org-agenda-layout-finalize)
    (should-not (overlays-in (point-min) (point-max)))))

(ert-deftest my/org-agenda-layout-extends-date-background ()
  "Agenda の日付の face を改行にも付け、他の行には付けない。"
  (with-temp-buffer
    (insert "2026/10/14 (水)\n  Development\n    SCHED\n")
    (goto-char (point-min))
    (setq-local major-mode 'org-agenda-mode)
    (setq-local org-agenda-current-span 'week)
    (let ((date-end (line-end-position))
          (original (buffer-string)))
      (put-text-property (point-min) date-end
                         'org-agenda-date-header t)
      (put-text-property (point-min) date-end
                         'face 'org-agenda-date-today)
      (should-not (get-text-property date-end 'face))
      (my/org-agenda-layout-finalize)
      (should (equal original (buffer-string)))
      (should (eq (get-text-property date-end 'face)
                  'org-agenda-date-today))
      (forward-line 1)
      (should-not (get-text-property (line-end-position) 'face))
      ;; 再描画しても日付 face の適用範囲は変わらない。
      (my/org-agenda-layout-finalize)
      (should (eq (get-text-property date-end 'face)
                  'org-agenda-date-today)))))

(ert-deftest my/org-agenda-layout-does-not-style-ordinary-headings ()
  "日付属性がない見出しや改行のない最終行には触れない。"
  (with-temp-buffer
    (insert "  Development\n2026/10/14 (水)")
    (goto-char (point-min))
    (put-text-property (point-min) (line-end-position)
                       'face 'org-agenda-structure)
    (forward-line 1)
    (let ((date-beg (line-beginning-position)))
      (put-text-property date-beg (point-max)
                         'org-agenda-date-header t)
      (put-text-property date-beg (point-max)
                         'face 'org-agenda-date)
      (my/org-agenda-layout--extend-date-background)
      (goto-char (point-min))
      (should-not (get-text-property (line-end-position) 'face))
      (forward-line 1)
      (should (eq (get-text-property (line-beginning-position) 'face)
                  'org-agenda-date)))))

(ert-deftest my/org-agenda-layout-block-separator-matches-vertical-border ()
  "複合 Agenda の横罫線だけを縦分割線と同じ face にする。"
  (with-temp-buffer
    (insert "2026/10/14 (水)\n────────\nGlobal list of TODO items of type: ALL\n")
    (setq-local major-mode 'org-agenda-mode)
    (let ((original (buffer-string)))
      (my/org-agenda-layout-style-block-separators)
      (should (equal (buffer-string) original))
      (goto-char (point-min))
      (should-not (get-text-property (point) 'face))
      (forward-line 1)
      (should (eq (get-text-property (point) 'face) 'vertical-border))
      (should (eq (get-text-property (1- (line-end-position)) 'face)
                  'vertical-border))
      (forward-line 1)
      (should-not (get-text-property (point) 'face))
      ;; 更新しても属性が重ならず、別の行まで装飾しない。
      (my/org-agenda-layout-style-block-separators)
      (forward-line -1)
      (should (eq (get-text-property (point) 'face) 'vertical-border)))))

(ert-deftest my/org-agenda-layout-block-separator-skips-other-lines ()
  "横罫線以外の行や別のバッファは変更しない。"
  (with-temp-buffer
    (insert "──────── item\n========\n")
    (setq-local major-mode 'org-agenda-mode)
    (my/org-agenda-layout-style-block-separators)
    (goto-char (point-min))
    (should-not (get-text-property (point) 'face))
    (forward-line 1)
    (should-not (get-text-property (point) 'face))))

;;; my-org-agenda-layout-test.el ends here
