;;; my-editing-test.el --- Tests for clipboard editing -*- lexical-binding: t; -*-

;;; Commentary:
;; 選択範囲の切り取りがキルリングとOSのクリップボードを更新することを確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-editing)


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


;;; my-editing-test.el ends here
