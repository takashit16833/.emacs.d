;;; my-clutch-fullscreen-test.el --- Fullscreen Clutch tests -*- lexical-binding: t; -*-

;;; Commentary:
;; DB接続なしでClutchと通常のbufferの切り替えを確認する。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-clutch-fullscreen)

(defmacro my/clutch-fullscreen-test--with-buffers (&rest body)
  "テスト用のClutchと編集バッファを作ってBODYを実行する。"
  (declare (indent 0))
  `(save-window-excursion
     (let ((editing (generate-new-buffer "clutch-test-editing"))
           (other (generate-new-buffer "clutch-test-other"))
           (clutch (generate-new-buffer "clutch-test-console")))
       (unwind-protect
           (progn
             (with-current-buffer clutch
               (setq major-mode 'clutch-mode))
             (delete-other-windows)
             (switch-to-buffer editing)
             (my/fullscreen-clear 'my/clutch-fullscreen)
             (my/fullscreen-clear 'my/clutch-layout)
             ,@body)
         (my/fullscreen-clear 'my/clutch-fullscreen)
         (my/fullscreen-clear 'my/clutch-layout)
         (dolist (buffer (list editing other clutch))
           (when (buffer-live-p buffer)
             (kill-buffer buffer)))))))

(ert-deftest my/clutch-fullscreen-opens-and-restores-split ()
  "Clutchを開くと全面表示し、tab-lineのbuffer移動で元の分割へ戻る。"
  (my/clutch-fullscreen-test--with-buffers
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen-open
     (lambda () (switch-to-buffer clutch)))
    (should (one-window-p t))
    (should (eq (current-buffer) clutch))
    (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
    (should (= (length (window-list)) 2))
    (should (eq (window-buffer (next-window)) other))))

(ert-deftest my/clutch-fullscreen-reopens-from-tab-line ()
  "編集bufferからClutchへ移動すると再び全面表示する。"
  (my/clutch-fullscreen-test--with-buffers
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
    (should (one-window-p t))
    (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
    (should (= (length (window-list)) 2))
    (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
    (should (one-window-p t))))

(ert-deftest my/clutch-fullscreen-allows-result-split ()
  "SQL結果の分割中も編集画面へ戻ると元の配置を復元する。"
  (my/clutch-fullscreen-test--with-buffers
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
    (let ((result (generate-new-buffer "clutch-test-result")))
      (unwind-protect
          (progn
            (with-current-buffer result (setq major-mode 'clutch-result-mode))
            (set-window-buffer (split-window-below) result)
            (should (= (length (window-list)) 2))
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (= (length (window-list)) 2))
            (should (eq (window-buffer (next-window)) other))
            ;; tab-lineからClutchへ戻るとSQL結果を含む上下分割が復元する。
            (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
            (should (= (length (window-list)) 2))
            (should (eq (window-buffer (selected-window)) clutch))
            (should (memq result (mapcar #'window-buffer (window-list))))
            ;; 繰り返し切り替えても配置を保持する。
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (eq (window-buffer (next-window)) other))
            (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
            (should (memq result (mapcar #'window-buffer (window-list))))
            ;; 再び編集側へ戻っても SQL 結果が混ざらない。
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (eq (window-buffer (next-window)) other)))
        (kill-buffer result)))))

(ert-deftest my/clutch-fullscreen-keeps-internal-buffer-transition ()
  "Clutchのqueryから結果へ移っても元の編集分割は復元しない。"
  (my/clutch-fullscreen-test--with-buffers
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
    (let ((result (generate-new-buffer "clutch-test-result")))
      (unwind-protect
          (progn
            (with-current-buffer result (setq major-mode 'clutch-result-mode))
            (my/clutch-fullscreen--around-switch #'switch-to-buffer result)
            (should (one-window-p t))
            (should (my/fullscreen-get 'my/clutch-fullscreen)))
        (kill-buffer result)))))


(ert-deftest my/clutch-fullscreen-keeps-editing-layout-across-switches ()
  "Clutchとの往復で編集画面の保存状態を破棄しない。"
  (my/clutch-fullscreen-test--with-buffers
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
    (let ((saved (my/fullscreen-get 'my/clutch-fullscreen)))
      (should (eq (car saved) clutch))
      (should (window-configuration-p (cdr saved)))
      (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
      (should (eq saved (my/fullscreen-get 'my/clutch-fullscreen)))
      (should (window-configuration-p
               (my/fullscreen-get 'my/clutch-layout)))
      (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
      (should (eq saved (my/fullscreen-get 'my/clutch-fullscreen)))
      (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
      (should (eq saved (my/fullscreen-get 'my/clutch-fullscreen))))))


(ert-deftest my/clutch-fullscreen-fresh-open-discards-old-clutch-layout ()
  "Clutchを新たに起動すると以前のSQL結果の分割を引き継がない。"
  (my/clutch-fullscreen-test--with-buffers
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
    (let ((result (generate-new-buffer "clutch-test-result")))
      (unwind-protect
          (progn
            (with-current-buffer result (setq major-mode 'clutch-result-mode))
            (set-window-buffer (split-window-below) result)
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (window-configuration-p
                     (my/fullscreen-get 'my/clutch-layout)))
            (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
            (should-not (my/fullscreen-get 'my/clutch-layout))
            (should (my/fullscreen-get 'my/clutch-fullscreen))
            (should (one-window-p t))
            (should (eq (window-buffer) clutch)))
        (kill-buffer result)))))


(provide 'my-clutch-fullscreen-test)

;;; my-clutch-fullscreen-test.el ends here
