;;; my-clutch-fullscreen.el --- Fullscreen Clutch with tab-line -*- lexical-binding: t; -*-

;;; Commentary:
;; vterm と共有するのは全面表示・配置保存の基本処理だけ。
;; Clutch は tab-line に表示され、バッファの切り替えでも開閉する。
;;
;; 現在の tab-bar タブに、用途の異なる2つの状態を保存する。
;; - my/clutch-fullscreen: (Clutchバッファ . 元の編集画面の配置)
;; - my/clutch-layout: SQL結果の分割を含むClutch画面の配置
;;
;; Clutchを離れるときは後者を保存し、前者を使って編集画面へ戻す。
;; 編集画面の配置はClutchへ入る直前の最新状態に更新する。
;; 初回の保存内容を使い回すと、ユーザーが閉じた分割が復活する。
;; 編集画面の保存状態自体は消さない。消すとClutchから戻れない。
;; 再度Clutchを起動した場合は両方を初期化する。
;; tab-lineの表示条件は my-tab-line.el が管理する。

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
  "保存済みのClutch画面を復元し、BUFFERのウィンドウを選択する。
結果ペインなど、BUFFER以外のClutchウィンドウはそのまま維持する。
復元できれば t、保存済みの配置がなければ nil を返す。"
  (when-let* ((layout (my/fullscreen-get 'my/clutch-layout)))
    (set-window-configuration layout)
    ;; 結果表示など他のClutchウィンドウを置き換えない。
    (if-let* ((window (get-buffer-window buffer)))
        (select-window window)
      (let ((my/clutch-fullscreen--inhibit t))
        (switch-to-buffer buffer)))
    t))

(defun my/clutch-fullscreen--leave (saved)
  "現在のClutch画面を保存し、SAVEDに記録された編集画面へ戻す。
SAVED は (Clutchバッファ . 編集画面の配置) の組。
ここでは `my/fullscreen-restore' を使わない。あちらは復元後に
保存状態を消すため、Clutchへの往復を繰り返せなくなる。"
  (setf (alist-get 'my/clutch-layout (cdr (my/fullscreen--tab)))
        (current-window-configuration))
  (set-window-configuration (cdr saved)))

(defun my/clutch-fullscreen--enter (buffer configuration)
  "BUFFERのClutch画面を表示する。
CONFIGURATIONは切り替え直前の最新の編集画面配置。
保存済みのClutch配置があれば復元し、なければ全面表示する。"
  ;; Clutch側の配置が存在しても編集画面側は毎回更新する。
  ;; 初回起動時の配置を使い回すと、後で閉じた分割が復活してしまう。
  (if (my/fullscreen-get 'my/clutch-layout)
      (progn
        (setf (alist-get 'my/clutch-fullscreen (cdr (my/fullscreen--tab)))
              (cons buffer configuration))
        (my/clutch-fullscreen--restore-layout buffer))
    (my/fullscreen-clear 'my/clutch-fullscreen)
    (my/fullscreen-enter 'my/clutch-fullscreen
                         (current-buffer) configuration)))

(defun my/clutch-fullscreen--around-switch (original buffer &rest args)
  "Clutch と通常の編集画面を切り替え、ORIGINAL を呼ぶ。
Clutchに戻るときはORIGINALの後でClutch配置を復元する。
先に復元するとORIGINALがクエリ表示を別バッファで上書きする。"
  (if my/clutch-fullscreen--inhibit
      (apply original buffer args)
    (let* ((target (if (bufferp buffer) buffer (get-buffer buffer)))
           (from-clutch (my/clutch-fullscreen--buffer-p (current-buffer)))
           (to-clutch (my/clutch-fullscreen--buffer-p target))
           (saved (my/fullscreen-get 'my/clutch-fullscreen))
           (entering (and to-clutch (not from-clutch)))
           (leaving (and from-clutch (not to-clutch) saved))
           (configuration (and entering (current-window-configuration))))
      ;; クエリと結果の間だけの移動は、Clutch内部の操作として扱う。
      (when leaving
        (my/clutch-fullscreen--leave saved))
      (let ((result (let ((my/clutch-fullscreen--inhibit t))
                      (apply original buffer args))))
        (when entering
          (my/clutch-fullscreen--enter target configuration))
        result))))

(defun my/clutch-fullscreen-open (open)
  "OPEN を実行してClutchを表示し、編集画面の配置を保存する。
新しく起動する際は以前のClutch画面・編集画面の保存状態を破棄する。"
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
  "Clutchを通常のバッファ切り替えでも全面表示する。
vtermの起動やtab-lineの除外条件には介入しない。"
  (unless (advice-member-p #'my/clutch-fullscreen--around-switch
                           'switch-to-buffer)
    (advice-add 'switch-to-buffer :around
                #'my/clutch-fullscreen--around-switch)))

(provide 'my-clutch-fullscreen)

;;; my-clutch-fullscreen.el ends here
