;;; my-editing-test.el --- Editing command tests -*- lexical-binding: t; -*-

;;; Commentary:
;; 行の選択・複製とOSクリップボードへの切り取りを確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-editing)


(ert-deftest my/select-to-line-beginning-uses-shift-selection ()
  "行頭移動をShift選択として呼び出す。"
  (let (called-command
        this-command-keys-shift-translated)
    (cl-letf (((symbol-function 'call-interactively)
               (lambda (command &rest _args)
                 (setq called-command command))))
      (my/select-to-line-beginning)
      (should this-command-keys-shift-translated)
      (should (eq called-command #'move-beginning-of-line)))))


(ert-deftest my/cut-region-to-clipboard-cuts-active-region ()
  "選択範囲を削除し、キルリングとクリップボードへ保存する。"
  (with-temp-buffer
    (insert "abCDxy")
    (goto-char 5)
    (set-mark 3)
    (activate-mark)

    (let ((transient-mark-mode t)
          (interprogram-cut-function nil)
          (kill-ring nil)
          (kill-ring-yank-pointer nil)
          clipboard)
      (cl-letf (((symbol-function 'gui-set-selection)
                 (lambda (type text)
                   (setq clipboard (cons type text)))))
        (my/cut-region-to-clipboard (region-beginning) (region-end))
        (should (equal (buffer-string) "abxy"))
        (should (equal (car kill-ring) "CD"))
        (should (equal clipboard '(CLIPBOARD . "CD")))))))


(ert-deftest my/cut-region-to-clipboard-requires-active-region ()
  "選択していない場合は何も削除しない。"
  (with-temp-buffer
    (insert "abc")
    (let ((transient-mark-mode t)
          (interprogram-cut-function nil))
      (deactivate-mark)
      (should-error
       (my/cut-region-to-clipboard (point-min) (point-max))
       :type 'user-error)
      (should (equal (buffer-string) "abc")))))


(ert-deftest my/duplicate-lines-down-preserves-column-at-final-line ()
  "改行のない最終行を下へ複製し、複製側の同じ列へ移動する。"
  (with-temp-buffer
    (insert "abc")
    (goto-char 2)
    (my/duplicate-lines-down)
    (should (equal (buffer-string) "abc\nabc"))
    (should (= (line-number-at-pos) 2))
    (should (= (current-column) 1))))


(ert-deftest my/duplicate-lines-up-preserves-column ()
  "現在行を上へ複製し、複製側の同じ列へ移動する。"
  (with-temp-buffer
    (insert "first\nsecond\n")
    (goto-char (+ (point-min) 7))
    (my/duplicate-lines-up)
    (should (equal (buffer-string) "first\nsecond\nsecond\n"))
    (should (= (line-number-at-pos) 2))
    (should (= (current-column) 1))))


;;; my-editing-test.el ends here
