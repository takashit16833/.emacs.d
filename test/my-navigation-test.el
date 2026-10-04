;;; my-navigation-test.el --- Tests for my-navigation -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-navigation' のテスト。

;;; Code:

(require 'ert)
(require 'cl-lib)

;; my-navigation の履歴記録ロジックだけを単体テストできるようにする。
;; 実際の browsing-history 関数は各テスト内で差し替える。
(unless (featurep 'browsing-history)
  (provide 'browsing-history))

(require 'my-navigation)


(ert-deftest my/navigation--track-records-source-and-destination ()
  "移動が成立した場合は移動元と移動先を順番に記録すること。"
  (with-temp-buffer
    (setq buffer-file-name "/tmp/navigation-test.el")
    (insert "abcdef")
    (goto-char 2)

    (let (pushed-locations)
      (cl-letf (((symbol-function 'make-browsing-history-location)
                 (lambda (&rest properties)
                   properties))
                ((symbol-function 'browsing-history-ensure-current)
                 (lambda () 'history))
                ((symbol-function 'browsing-history-push)
                 (lambda (history location)
                   (should (eq history 'history))
                   (setq pushed-locations
                         (append pushed-locations (list location))))))
        (my/navigation--track
         (lambda ()
           (goto-char 5)))

        (should (= (length pushed-locations) 2))
        (should (equal (plist-get (nth 0 pushed-locations) :file)
                       "/tmp/navigation-test.el"))
        (should (= (plist-get (nth 0 pushed-locations) :position) 2))
        (should (= (plist-get (nth 1 pushed-locations) :position) 5))

        ;; テストで作った marker をバッファから切り離す。
        (dolist (location pushed-locations)
          (set-marker (plist-get location :marker) nil))))))


(ert-deftest my/navigation--track-does-not-record-without-movement ()
  "位置が変わらなかった場合は履歴を記録しないこと。"
  (with-temp-buffer
    (setq buffer-file-name "/tmp/navigation-test.el")
    (insert "abcdef")
    (goto-char 2)

    (let ((called-p nil))
      (cl-letf (((symbol-function 'browsing-history-ensure-current)
                 (lambda ()
                   (setq called-p t)
                   'history)))
        (my/navigation--track (lambda () 'result))
        (should-not called-p)))))


(ert-deftest my/navigation--track-does-not-record-recursively ()
  "履歴記録中に呼ばれた移動は重複して記録しないこと。"
  (with-temp-buffer
    (setq buffer-file-name "/tmp/navigation-test.el")
    (insert "abcdef")
    (goto-char 2)

    (let ((my/navigation--tracking t)
          (called-p nil))
      (cl-letf (((symbol-function 'browsing-history-ensure-current)
                 (lambda ()
                   (setq called-p t)
                   'history)))
        (my/navigation--track
         (lambda ()
           (goto-char 5)))
        (should-not called-p)))))


;;; my-navigation-test.el ends here
