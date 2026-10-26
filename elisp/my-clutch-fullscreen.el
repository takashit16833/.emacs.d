;;; my-clutch-fullscreen.el --- Fullscreen Clutch with tab-line -*- lexical-binding: t; -*-

;;; Commentary:
;; Clutch は tab-line に残し、通常のバッファへ戻ると編集画面を復元する。
;; SQL実行結果は clutch-result-mode なので全面表示内部で分割できる。
;; vterm と配置保存・復元だけを共有する。起動や tab-line 除外条件は共有しない。

;;; Code:

(require 'my-fullscreen-buffer)

(defvar my/clutch-fullscreen--inhibit nil
  "Clutch 起動中など、一時的にバッファ切り替えの監視を止める。")

(defun my/clutch-fullscreen--buffer-p (buffer)
  "BUFFER が Clutch の画面なら non-nil を返す。"
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (or (derived-mode-p 'clutch-mode)
             (derived-mode-p 'clutch-result-mode)
             (derived-mode-p 'clutch-repl-mode)
             (derived-mode-p 'clutch-record-mode)))))

(defun my/clutch-fullscreen--restore-layout (buffer)
  "Clutchの保存済み配置を戻し、BUFFERのウィンドウを選択する。"
  (when-let* ((layout (my/fullscreen-get 'my/clutch-layout)))
    (set-window-configuration layout)
    ;; 結果表示など他のClutchウィンドウを置き換えない。
    (if-let* ((window (get-buffer-window buffer)))
        (select-window window)
      (let ((my/clutch-fullscreen--inhibit t))
        (switch-to-buffer buffer)))
    t))

(defun my/clutch-fullscreen--around-switch (original buffer &rest args)
  "Clutch と通常の編集画面を切り替え、ORIGINAL を呼ぶ。"
  (if my/clutch-fullscreen--inhibit
      (apply original buffer args)
    (let* ((target (if (bufferp buffer) buffer (get-buffer buffer)))
           (from-clutch (my/clutch-fullscreen--buffer-p (current-buffer)))
           (to-clutch (my/clutch-fullscreen--buffer-p target))
           (saved (my/fullscreen-get 'my/clutch-fullscreen))
           (entering (and to-clutch (not from-clutch)))
           (leaving (and from-clutch (not to-clutch) saved))
           (configuration (and entering (current-window-configuration))))
      ;; Clutch内のクエリ→結果の切り替えでは元の分割へ戻さない。
      (when leaving
        ;; SQL結果を含むClutch内部のウィンドウ配置を保存する。
        (setf (alist-get 'my/clutch-layout (cdr (my/fullscreen--tab)))
              (current-window-configuration))
        (my/fullscreen-restore 'my/clutch-fullscreen t))
      (let ((result (let ((my/clutch-fullscreen--inhibit t))
                      (apply original buffer args))))
        (when entering
          (unless (my/clutch-fullscreen--restore-layout target)
            (my/fullscreen-clear 'my/clutch-fullscreen)
            (my/fullscreen-enter 'my/clutch-fullscreen
                                 (current-buffer) configuration)))
        result))))

(defun my/clutch-fullscreen-open (open)
  "OPEN を実行して Clutch を表示し、元の編集配置を保存する。"
  (let ((configuration (current-window-configuration)))
    (let ((my/clutch-fullscreen--inhibit t))
      (funcall open))
    (when (my/clutch-fullscreen--buffer-p (current-buffer))
      ;; 新しく開いたコンソールは以前のClutch画面の配置を引き継がない。
      (my/fullscreen-clear 'my/clutch-layout)
      (my/fullscreen-clear 'my/clutch-fullscreen)
      (my/fullscreen-enter 'my/clutch-fullscreen
                           (current-buffer) configuration))))

(defun my/clutch-fullscreen-setup ()
  "Clutchを通常のbuffer切り替えでも全面表示する。"
  (unless (advice-member-p #'my/clutch-fullscreen--around-switch
                           'switch-to-buffer)
    (advice-add 'switch-to-buffer :around
                #'my/clutch-fullscreen--around-switch)))

(provide 'my-clutch-fullscreen)

;;; my-clutch-fullscreen.el ends here
