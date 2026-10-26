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
              ;; 編集画面の保存状態はClutchへ入るたびに更新される。
              ;; 戻るときに保存状態が失われないことを各往復で確認する。
              (let ((snapshot (my/fullscreen-get 'my/clutch-fullscreen)))
                (my/clutch-fullscreen--around-switch #'switch-to-buffer editing)
                (should (one-window-p t))
                (should (eq (window-buffer) editing))
                (should (eq snapshot (my/fullscreen-get 'my/clutch-fullscreen)))
                (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
                (should (= (length (window-list)) 2))
                (should (eq (window-buffer (selected-window)) clutch))
                (should (memq result (mapcar #'window-buffer (window-list)))))))
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



(ert-deftest my/clutch-fullscreen-tab-line-restores-last-selected-editor-pane ()
  "巡回先を表示しつつ、Clutchへ入る直前の編集ペインを選択する。"
  (my/clutch-fullscreen-test--with-buffers
    (let ((tab-line-tabs-function (lambda () (list editing other clutch)))
          (tab-line-switch-cycling t))
      (let ((lower (split-window-below)))
        (set-window-buffer lower other)
        ;; 下からClutchへ移動したら、前のタブotherが下ペインで選択される。
        (select-window lower)
        (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
        (my/clutch-fullscreen-tab-line-prev)
        (should (= (length (window-list)) 2))
        (should (eq (window-buffer) other))
        (should (window-in-direction 'above))
        ;; 上から入り直したら、次のタブeditingが上で選択される。
        (select-window (get-buffer-window editing))
        (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
        (my/clutch-fullscreen-tab-line-next)
        (should (= (length (window-list)) 2))
        (should (eq (window-buffer) editing))
        (should (window-in-direction 'below))
        ;; 再び下から切り替えても、古い上側の選択状態に戻らない。
        (select-window (get-buffer-window other))
        (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
        (my/clutch-fullscreen-tab-line-prev)
        (should (eq (window-buffer) other))
        (should (window-in-direction 'above))
        (should (= (length (window-list)) 2))))))

(ert-deftest my/clutch-fullscreen-tab-line-keeps-query-result-split ()
  "巡回順序を守りつつSQL結果用のClutch内分割も維持する。"
  (my/clutch-fullscreen-test--with-buffers
    (let ((tab-line-tabs-function (lambda () (list editing other clutch)))
          (tab-line-switch-cycling t))
      (set-window-buffer (split-window-below) other)
      (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
      (let ((result (generate-new-buffer "clutch-test-result")))
        (unwind-protect
            (progn
              (with-current-buffer result
                (setq major-mode 'clutch-result-mode))
              (set-window-buffer (split-window-below) result)
              ;; Clutchの次は一覧の先頭editing。
              (my/clutch-fullscreen-tab-line-next)
              (should (= (length (window-list)) 2))
              (should (eq (window-buffer) editing))
              ;; 下の編集ペインから入り直しても結果ペインが残る。
              (select-window (get-buffer-window other))
              (my/clutch-fullscreen--around-switch #'switch-to-buffer clutch)
              (should (memq result (mapcar #'window-buffer (window-list))))
              ;; Clutchの前はotherであり、元の選択ペインも下。
              (my/clutch-fullscreen-tab-line-prev)
              (should (eq (window-buffer) other))
              (should (window-in-direction 'above))
              (should (= (length (window-list)) 2)))
          (kill-buffer result))))))

(ert-deftest my/clutch-fullscreen-tab-line-delegates-outside-clutch ()
  "通常バッファではC-<tab>とC-S-<tab>が標準関数を使う。"
  (my/clutch-fullscreen-test--with-buffers
    (let (calls)
      (cl-letf (((symbol-function 'tab-line-switch-to-next-tab)
                 (lambda (&optional _event _arg)
                   (interactive)
                   (push 'next calls)))
                ((symbol-function 'tab-line-switch-to-prev-tab)
                 (lambda (&optional _event _arg)
                   (interactive)
                   (push 'prev calls))))
        (my/clutch-fullscreen-tab-line-next)
        (my/clutch-fullscreen-tab-line-prev)
        (should (equal calls '(prev next)))))))


(ert-deftest my/clutch-fullscreen-tab-line-cycles-through-every-buffer ()
  "Clutchを含む表示順にC-<tab>で巡回し、2バッファ間で往復しない。"
  (my/clutch-fullscreen-test--with-buffers
    (let ((migrate (generate-new-buffer "clutch-test-migrate")))
      (unwind-protect
          (let ((tab-line-tabs-function
                 (lambda () (list editing other migrate clutch)))
                (tab-line-switch-cycling t))
            (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
            ;; Clutchは最後のタブ: 次は先頭のediting。
            (my/clutch-fullscreen-tab-line-next)
            (should (eq (current-buffer) editing))
            (my/clutch-fullscreen-tab-line-next)
            (should (eq (current-buffer) other))
            (my/clutch-fullscreen-tab-line-next)
            (should (eq (current-buffer) migrate))
            (my/clutch-fullscreen-tab-line-next)
            (should (eq (current-buffer) clutch))
            (my/clutch-fullscreen-tab-line-next)
            (should (eq (current-buffer) editing))
            ;; 逆方向にも表示順どおりに戻れる。
            (my/clutch-fullscreen-tab-line-prev)
            (should (eq (current-buffer) clutch))
            (my/clutch-fullscreen-tab-line-prev)
            (should (eq (current-buffer) migrate)))
        (kill-buffer migrate)))))


(ert-deftest my/clutch-fullscreen-tab-line-respects-no-wrap ()
  "巡回なしの場合、末尾のClutchから次へ進んでも編集画面へ戻さない。"
  (my/clutch-fullscreen-test--with-buffers
    (let ((tab-line-tabs-function (lambda () (list editing other clutch)))
          (tab-line-switch-cycling nil))
      (my/clutch-fullscreen-open (lambda () (switch-to-buffer clutch)))
      (my/clutch-fullscreen-tab-line-next)
      (should (eq (current-buffer) clutch))
      (should (one-window-p t)))))


(provide 'my-clutch-fullscreen-test)

;;; my-clutch-fullscreen-test.el ends here
