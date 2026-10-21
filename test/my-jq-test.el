;;; my-jq-test.el --- jq Playground tests -*- lexical-binding: t; -*-

;;; Commentary:
;; jq確認用バッファの作成、再利用、選択範囲の取り込みを確認する。

;;; Code:

(require 'ert)
(require 'my-jq)


(ert-deftest my/jq-playground-creates-and-reuses-json-buffer ()
  "Playgroundの再起動でJSONを消さず、通常のキーマップも変更しない。"
  (let ((name "*jq-playground*"))
    (when (get-buffer name)
      (kill-buffer name))
    (unwind-protect
        (save-window-excursion
          (my/jq-playground)
          (should (equal (buffer-name) name))
          (should (derived-mode-p 'js-json-mode))
          (should (equal (buffer-string) "[]\n"))
          (should (eq (key-binding (kbd "C-c C-j"))
                      #'jq-interactively))
          (should-not (eq (current-local-map) js-json-mode-map))
          (erase-buffer)
          (insert "{\"message\":\"hello\"}\n")
          (let ((buffer (current-buffer)))
            (my/jq-playground)
            (should (eq (current-buffer) buffer))
            (should (equal (buffer-string)
                           "{\"message\":\"hello\"}\n"))))
      (when (get-buffer name)
        (kill-buffer name)))))


(ert-deftest my/jq-playground-imports-selected-region ()
  "選択範囲をそのまま取り込み、元のバッファには触れない。"
  (let ((name "*jq-playground*"))
    (when (get-buffer name)
      (kill-buffer name))
    (unwind-protect
        (save-window-excursion
          (with-temp-buffer
            (insert "before not-json after")
            (let ((source (current-buffer))
                  (original (buffer-string)))
              (goto-char (+ (point-min) (length "before ")))
              (set-mark (+ (point) (length "not-json")))
              (setq mark-active t)
              (let ((transient-mark-mode t))
                (should (use-region-p))
                (my/jq-playground))
              (should (equal (buffer-name) name))
              ;; JSONとしての妥当性は検証せず、選択文字列をそのまま使う。
              (should (equal (buffer-string) "not-json"))
              (should (eq (key-binding (kbd "C-c C-j"))
                          #'jq-interactively))
              (with-current-buffer source
                (should (equal (buffer-string) original))))))
      (when (get-buffer name)
        (kill-buffer name)))))


(ert-deftest my/jq-playground-selected-region-replaces-existing-content ()
  "既存のPlaygroundへ取り込むときは内容を置き換える。"
  (let ((name "*jq-playground*"))
    (when (get-buffer name)
      (kill-buffer name))
    (unwind-protect
        (save-window-excursion
          (my/jq-playground)
          (erase-buffer)
          (insert "{\"old\":true}")
          (with-temp-buffer
            (insert "ignore {\"new\":1} ignore")
            (goto-char (+ (point-min) (length "ignore ")))
            (set-mark (+ (point) (length "{\"new\":1}")))
            (setq mark-active t)
            (let ((transient-mark-mode t))
              (should (use-region-p))
              (my/jq-playground))
            (should (equal (buffer-name) name))
            (should (equal (buffer-string) "{\"new\":1}"))))
      (when (get-buffer name)
        (kill-buffer name)))))


;;; my-jq-test.el ends here
