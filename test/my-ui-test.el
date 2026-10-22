;;; my-ui-test.el --- Display table helper tests -*- lexical-binding: t; -*-

;;; Commentary:
;; 行番号表示に応じた境界線の切り替えを確認する。

;;; Code:

(require 'ert)
(require 'disp-table)
(require 'my-ui)

(ert-deftest my/update-vertical-border-hides-line-with-numbers ()
  "行番号を表示するとバッファ境界線を隠し、標準テーブルは変更しない。"
  (let ((standard-display-table (make-display-table)))
    (set-display-table-slot standard-display-table 'vertical-border ?│)
    (with-temp-buffer
      (setq-local display-line-numbers-mode t)
      (my/update-vertical-border)
      (should (eq (display-table-slot buffer-display-table 'vertical-border)
                  ?\s))
      (should (eq (display-table-slot standard-display-table 'vertical-border)
                  ?│))
      (setq-local display-line-numbers-mode nil)
      (my/update-vertical-border)
      (should (eq (display-table-slot buffer-display-table 'vertical-border)
                  ?│)))))

;;; my-ui-test.el ends here
