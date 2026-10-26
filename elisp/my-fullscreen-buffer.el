;;; my-fullscreen-buffer.el --- Tab-local fullscreen buffer layouts -*- lexical-binding: t; -*-

;;; Commentary:
;; vterm と Clutch で使う、タブ単位の配置保存・復元の共通部分。
;; KEY ごとに (対象バッファ . 元のウィンドウ配置) を保持する。
;;
;; `my/fullscreen-restore' は復元時に KEY の保存状態を消す（vterm向け）。
;; Clutch は複数回の往復で編集画面の配置を使い続けるため、
;; my-clutch-fullscreen.el から保存済み配置を直接復元する。
;; ここではClutch内部のSQL結果ペインやtab-lineの表示条件は扱わない。

;;; Code:

(require 'tab-bar)

(defun my/fullscreen--tab ()
  "現在の tab-bar タブを返す。"
  (assq 'current-tab (tab-bar-tabs)))

(defun my/fullscreen-get (key)
  "現在のタブの KEY に保存された全面表示状態を返す。"
  (alist-get key (cdr (my/fullscreen--tab))))

(defun my/fullscreen-clear (key)
  "現在のタブの KEY に保存された状態を破棄する。"
  (setf (alist-get key (cdr (my/fullscreen--tab))) nil))

(defun my/fullscreen-enter (key buffer &optional configuration)
  "BUFFER を全面表示し、KEY に元の配置を保存する。
CONFIGURATION があれば、バッファ表示前に保存した配置を使う。
CONFIGURATION が明示されていれば、現在が単一ウィンドウでも保存する。
省略時は分割されている場合だけ保存する（vterm の従来動作）。"
  (let ((window (get-buffer-window buffer)))
    (when window
      (select-window window)
      (let ((split (not (one-window-p t))))
        ;; Clutchは起動前の編集画面が単一ウィンドウでも復元する必要がある。
        ;; 現在の分割だけで判定すると、SQL結果の分割が編集画面に混ざる。
        (when (or split configuration)
          (let ((saved (or configuration (current-window-configuration))))
            (when split
              (delete-other-windows window))
            (setf (alist-get key (cdr (my/fullscreen--tab)))
                  (cons buffer saved)))))
      (selected-window))))

(defun my/fullscreen-restore (key &optional allow-split)
  "KEY の元のウィンドウ配置を復元する。
ALLOW-SPLIT が非 nil なら、全面表示中の一時的な分割も許可する。
状態がなければ何もしない。"
  (when-let* ((saved (my/fullscreen-get key)))
    (when (or allow-split (one-window-p t))
      (my/fullscreen-clear key)
      (set-window-configuration (cdr saved))
      t)))

(provide 'my-fullscreen-buffer)

;;; my-fullscreen-buffer.el ends here
