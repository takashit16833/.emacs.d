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
  "編集画面の保存状態はClutchへ戻るたびに更新し、離れても消さない。"
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
      (let ((latest (my/fullscreen-get 'my/clutch-fullscreen)))
        ;; 同じ分割でも、切り替え直前の配置を新しく保存する。
        (should-not (eq saved latest))
        (should (eq (car latest) clutch))
        (should (window-configuration-p (cdr latest)))
        (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
        (should (eq latest (my/fullscreen-get 'my/clutch-fullscreen)))))))


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



(ert-deftest my/clutch-fullscreen-one-window-editor-preserves-result-split ()
  "単一ウィンドウから起動してもClutchのSQL結果を編集画面に混ぜない。"
  (my/clutch-fullscreen-test--with-buffers
    (should (one-window-p t))
    (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
    (let ((saved (my/fullscreen-get 'my/clutch-fullscreen))
          (result (generate-new-buffer "clutch-test-result")))
      (unwind-protect
          (progn
            ;; 起動後はClutchだけの1ウィンドウでも、編集画面は保存済み。
            (should (eq (car saved) clutch))
            (should (window-configuration-p (cdr saved)))
            (with-current-buffer result
              (setq major-mode 'clutch-result-mode))
            (set-window-buffer (split-window-below) result)
            ;; 報告された操作: SQL実行後のC-<tab>を3往復。
            (dotimes (_ 3)
              (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
              (should (one-window-p t))
              (should (eq (window-buffer) editing))
              (should (eq saved (my/fullscreen-get 'my/clutch-fullscreen)))
              (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
              (should (= (length (window-list)) 2))
              (should (eq (window-buffer (selected-window)) clutch))
              (should (memq result (mapcar #'window-buffer (window-list))))))
        (kill-buffer result)))))


(ert-deftest my/clutch-fullscreen-one-window-tab-line-entry ()
  "既存のClutchバッファへ直接切り替えた場合も編集画面を保存する。"
  (my/clutch-fullscreen-test--with-buffers
    (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
    (should (one-window-p t))
    (should (my/fullscreen-get 'my/clutch-fullscreen))
    (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
    (should (one-window-p t))
    (should (eq (window-buffer) editing))))


(ert-deftest my/clutch-fullscreen-updates-edited-window-splits ()
  "編集画面で削除・追加した分割を復元し、SQL結果の分割は独立に維持する。"
  (my/clutch-fullscreen-test--with-buffers
    ;; 最初は編集中のファイルを横に2分割している。
    (set-window-buffer (split-window-right) other)
    (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
    (let ((result (generate-new-buffer "clutch-test-result")))
      (unwind-protect
          (progn
            (with-current-buffer result (setq major-mode 'clutch-result-mode))
            (set-window-buffer (split-window-below) result)
            ;; 編集画面に戻って右のウィンドウを閉じる。
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (= (length (window-list)) 2))
            (delete-other-windows)
            (should (one-window-p t))
            (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
            (should (= (length (window-list)) 2))
            (should (memq result (mapcar #'window-buffer (window-list))))
            ;; 往復しても、閉じた右ウィンドウが復活しない。
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (one-window-p t))
            (should (eq (window-buffer) editing))
            ;; 今度は右のウィンドウを作り直す。
            (set-window-buffer (split-window-right) other)
            (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
            (should (memq result (mapcar #'window-buffer (window-list))))
            (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
            (should (= (length (window-list)) 2))
            (should (eq (window-buffer) editing))
            (should (eq (window-buffer (next-window)) other)))
        (kill-buffer result)))))


(provide 'my-clutch-fullscreen-test)

;;; my-clutch-fullscreen-test.el ends here
