;;; my-vterm-test.el --- Tests for my-vterm -*- lexical-binding: t; -*-

;;; Commentary:
;; vtermの実プロセスを起動せず、表示先と分割の復元を検証する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-vterm)


(defmacro my/vterm-test--with-buffers (&rest body)
  "テスト用のバッファとvterm起動の代役を使ってBODYを実行する。"
  (declare (indent 0))
  `(save-window-excursion
     (let* ((project-current-directory-override
             (make-temp-name (expand-file-name "vterm-test-" temporary-file-directory)))
            (buffer-name (my/vterm--buffer-name project-current-directory-override))
            (buffer-a (generate-new-buffer "*my-vterm-a*"))
            (buffer-b (generate-new-buffer "*my-vterm-b*"))
            (created nil))
       (unwind-protect
           (cl-letf (((symbol-function 'vterm)
                      (lambda (&optional arg)
                        (let ((buffer (if arg
                                          (generate-new-buffer vterm-buffer-name)
                                        (get-buffer-create vterm-buffer-name))))
                          (push buffer created)
                          (with-current-buffer buffer
                            (setq major-mode 'vterm-mode))
                          (switch-to-buffer buffer)
                          buffer))))
             (my/fullscreen-clear 'my/vterm-fullscreen)
             (my/fullscreen-clear 'my/vterm-layout)
             (delete-other-windows)
             (switch-to-buffer buffer-a)
             ,@body)
         (my/fullscreen-clear 'my/vterm-fullscreen)
         (my/fullscreen-clear 'my/vterm-layout)
         (dolist (buffer (append created (list buffer-a buffer-b)))
           (when (buffer-live-p buffer)
             (kill-buffer buffer)))))))


(ert-deftest my/vterm-toggle-restores-split ()
  "通常起動は全面表示し、再実行で元の編集画面を戻す。"
  (my/vterm-test--with-buffers
    (set-window-buffer (split-window-right) buffer-b)
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (equal (buffer-name (window-buffer)) buffer-name))
    (my/vterm-toggle)
    (should (= (length (window-list)) 2))
    (should (eq (window-buffer (selected-window)) buffer-a))
    (should (eq (window-buffer (next-window)) buffer-b))))


(ert-deftest my/vterm-toggle-windmove-keeps-split ()
  "windmoveで右を指定したときは分割状態を維持する。"
  (my/vterm-test--with-buffers
    (let* ((left (selected-window))
           (right (split-window-right)))
      (set-window-buffer right buffer-b)
      (let ((exit (windmove-display-right)))
        (unwind-protect
            (progn
              (my/vterm-toggle)
              (should (= (length (window-list)) 2))
              (should (eq (selected-window) right))
              (should (eq (window-buffer left) buffer-a))
              (should (eq (window-buffer right) (get-buffer buffer-name))))
          (funcall exit)))
      (my/vterm-toggle)
      (should (= (length (window-list)) 2))
      (should (eq (selected-window) right))
      (should (eq (window-buffer left) buffer-a))
      (should (eq (window-buffer right) buffer-b)))))


(ert-deftest my/vterm-toggle-one-window ()
  "単一ウィンドウからでも編集画面へ戻り、再度vtermを開ける。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (my/fullscreen-get 'my/vterm-fullscreen))
    (my/vterm-toggle)
    (should (one-window-p t))
    (should (eq (window-buffer) buffer-a))
    (my/vterm-toggle)
    (should (equal (buffer-name (window-buffer)) buffer-name))))


(ert-deftest my/vterm-split-and-toggle-restores-both-layouts ()
  "vtermを分割した後、s-j相当の切り替えで両方の配置が復元される。"
  (my/vterm-test--with-buffers
    (set-window-buffer (split-window-right) buffer-b)
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below))))
        (my/vterm-split))
      (let ((second (current-buffer)))
        (should-not (eq first second))
        (should (= (length (window-list)) 2))
        (should (get-buffer-window first))
        (my/vterm-toggle)
        (should (= (length (window-list)) 2))
        (should (eq (current-buffer) buffer-a))
        (should (get-buffer-window buffer-b))
        (my/vterm-toggle)
        (should (= (length (window-list)) 2))
        (should (eq (current-buffer) second))
        (should (get-buffer-window first))
        (should (get-buffer-window second))))))


(ert-deftest my/vterm-split-only-in-vterm ()
  "vterm以外では分割コマンドが実行できない。"
  (my/vterm-test--with-buffers
    (should-error (my/vterm-split) :type 'user-error)
    (should (one-window-p t))))


(ert-deftest my/vterm-split-fails-without-space ()
  "分割できない場合は既存の画面を変更しない。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional _window) nil)))
        (should-error (my/vterm-split) :type 'user-error))
      (should (one-window-p t))
      (should (eq (current-buffer) first)))))


(ert-deftest my/vterm-split-rolls-back-on-startup-error ()
  "新しいvtermの起動失敗時は分割したウィンドウを閉じる。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below)))
                ((symbol-function 'vterm)
                 (lambda (&optional _arg)
                   (error "Test startup error"))))
        (should-error (my/vterm-split) :type 'error))
      (should (one-window-p t))
      (should (eq (current-buffer) first)))))


(ert-deftest my/vterm-toggle-restores-surviving-secondary-after-primary-exit ()
  "最初のvtermを終了しても、編集画面と生きているvtermを往復できる。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below))))
        (my/vterm-split))
      (let ((second (current-buffer)))
        (should (not (eq first second)))
        (kill-buffer first)
        (should-not (buffer-live-p first))
        (should (get-buffer-window second))
        (select-window (get-buffer-window second))
        (my/vterm-toggle)
        (should (one-window-p t))
        (should (eq (current-buffer) buffer-a))
        (my/vterm-toggle)
        (should (one-window-p t))
        (should (eq (current-buffer) second))
        (should-not (get-buffer buffer-name))
        (my/vterm-toggle)
        (should (eq (current-buffer) buffer-a))))))


(ert-deftest my/vterm-toggle-restores-primary-after-secondary-exit ()
  "追加したvtermを終了した場合も、残ったvtermだけが復元される。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below))))
        (my/vterm-split))
      (let ((second (current-buffer)))
        (kill-buffer second)
        (select-window (get-buffer-window first))
        (my/vterm-toggle)
        (should (eq (current-buffer) buffer-a))
        (my/vterm-toggle)
        (should (one-window-p t))
        (should (eq (current-buffer) first))))))


(ert-deftest my/vterm-toggle-after-last-vterm-exit ()
  "最後のvtermを終了しても編集画面に戻り、次は新しく起動できる。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (kill-buffer first)
      (should-not (buffer-live-p first))
      (my/vterm-toggle)
      (should (eq (current-buffer) buffer-a))
      (should-not (my/fullscreen-get 'my/vterm-layout))
      (my/vterm-toggle)
      (should (equal (buffer-name (current-buffer)) buffer-name)))))

(ert-deftest my/vterm-tab-line-only-shows-related-terminals ()
  "同じvterm画面のターミナルだけをtab-lineに並べる。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer))
          (other (generate-new-buffer "*vterm:unrelated*")))
      (unwind-protect
          (progn
            (with-current-buffer first
              (my/vterm-tab-line-setup)
              (should (eq tab-line-tabs-function #'my/vterm-tab-line-tabs)))
            (with-current-buffer other
              (setq major-mode 'vterm-mode)
              (setq-local my/vterm-tab-line-group "unrelated"))
            (cl-letf (((symbol-function 'split-window-sensibly)
                       (lambda (&optional window)
                         (split-window window nil 'below))))
              (my/vterm-split))
            (let ((second (current-buffer)))
              (should-not (eq first second))
              (dolist (buffer (list first second))
                (with-current-buffer buffer
                  (let ((tabs (my/vterm-tab-line-tabs)))
                    (should (= (length tabs) 2))
                    (should (memq first tabs))
                    (should (memq second tabs))
                    (should-not (memq other tabs)))))
              (with-current-buffer other
                (should (equal (my/vterm-tab-line-tabs)
                               (list other))))))
        (kill-buffer other)))))


(ert-deftest my/vterm-tab-line-drops-closed-terminal ()
  "終了したvtermは同じグループのtab-lineから消える。"
  (my/vterm-test--with-buffers
    (my/vterm-toggle)
    (let ((first (current-buffer)))
      (cl-letf (((symbol-function 'split-window-sensibly)
                 (lambda (&optional window)
                   (split-window window nil 'below))))
        (my/vterm-split))
      (let ((second (current-buffer)))
        (kill-buffer first)
        (should (equal (my/vterm-tab-line-tabs) (list second)))))))

(ert-deftest my/vterm-tab-line-order-ignores-buffer-list-recency ()
  "使用順が変わっても既存のvtermタブの順番を維持する。"
  (let* ((a (generate-new-buffer "*vterm:order-a*"))
         (b (generate-new-buffer "*vterm:order-b*"))
         (c (generate-new-buffer "*vterm:order-c*"))
         (tab (list 'current-tab))
         (buffers (list a b)))
    (unwind-protect
        (progn
          (dolist (buffer (list a b c))
            (with-current-buffer buffer
              (setq major-mode 'vterm-mode)
              (setq-local my/vterm-tab-line-group "test-group")))
          (cl-letf (((symbol-function 'tab-bar-tabs)
                     (lambda () (list tab)))
                    ((symbol-function 'buffer-list)
                     (lambda (&optional _frame) buffers)))
            (with-current-buffer a
              (should (equal (my/vterm-tab-line-tabs) (list a b)))
              ;; Cに切り替えた場合も、新しいタブは末尾に追加する。
              (setq buffers (list c b a))
              (should (equal (my/vterm-tab-line-tabs) (list a b c)))
              ;; Bが終了した場合は、並び順を保って候補から外す。
              (setq buffers (list c a))
              (should (equal (my/vterm-tab-line-tabs) (list a c))))))
      (dolist (buffer (list a b c))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))


(ert-deftest my/vterm-tab-line-order-isolated-between-tabs ()
  "同じvtermグループでもtab-barタブごとに順番を独立させる。"
  (let* ((a (generate-new-buffer "*vterm:tab-a*"))
         (b (generate-new-buffer "*vterm:tab-b*"))
         (other (generate-new-buffer "*vterm:other-group*"))
         (tab-a (list 'current-tab))
         (tab-b (list 'current-tab))
         (active-tab tab-a)
         (buffers (list a b other)))
    (unwind-protect
        (progn
          (dolist (buffer (list a b))
            (with-current-buffer buffer
              (setq major-mode 'vterm-mode)
              (setq-local my/vterm-tab-line-group "shared")))
          (with-current-buffer other
            (setq major-mode 'vterm-mode)
            (setq-local my/vterm-tab-line-group "other"))
          (cl-letf (((symbol-function 'tab-bar-tabs)
                     (lambda () (list active-tab)))
                    ((symbol-function 'buffer-list)
                     (lambda (&optional _frame) buffers)))
            (with-current-buffer a
              (should (equal (my/vterm-tab-line-tabs) (list a b))))
            (setq active-tab tab-b
                  buffers (list b other a))
            (with-current-buffer b
              (should (equal (my/vterm-tab-line-tabs) (list b a))))
            (setq active-tab tab-a)
            (with-current-buffer a
              (should (equal (my/vterm-tab-line-tabs) (list a b))))
            (with-current-buffer other
              (should (equal (my/vterm-tab-line-tabs) (list other))))))
      (dolist (buffer (list a b other))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

;;; my-vterm-test.el ends here
