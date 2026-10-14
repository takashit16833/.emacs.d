;;; my-navigation.el --- Navigation helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Browsing History など、移動に関する独自コマンドを定義する。

;;; Code:

(require 'browsing-history)


(defvar my/navigation--tracking nil
  "Browsing History の記録処理中は非nil。")


(defun my/navigation--track (original &rest args)
  "ORIGINAL による移動が成立したときだけ Browsing History に記録する。"
  (if my/navigation--tracking
      (apply original args)
    (let ((my/navigation--tracking t)
          (source-buffer (current-buffer))
          (source-window (selected-window))
          (source-position (point))
          (source-location (browsing-history-location-at-point)))
      (let ((result (apply original args)))
        ;; 同じウィンドウ内で、実際に位置が変わった場合だけ記録する。
        (when (and (eq source-window (selected-window))
                   (or (not (eq source-buffer (current-buffer)))
                       (/= source-position (point))))
          (let ((history (browsing-history-ensure-current)))
            ;; 移動元と移動先の両方を記録することで、
            ;; 移動直後から back で移動元へ戻れるようにする。
            (browsing-history-push history source-location)
            (browsing-history-push
             history
             (browsing-history-location-at-point))))
        result))))


(defun my/navigation--advise (command)
  "COMMAND の移動を Browsing History に記録する advice を設定する。"
  (unless (advice-member-p #'my/navigation--track command)
    (advice-add command :around #'my/navigation--track)))


(defun my/navigation-setup ()
  "バッファ切り替えと明示的なジャンプの履歴記録を設定する。"
  ;; Emacs 標準の移動。
  (dolist (command '(find-file switch-to-buffer goto-line))
    (my/navigation--advise command))

  ;; Project。
  (with-eval-after-load 'project
    (my/navigation--advise 'project-find-file))

  ;; Xref。
  (with-eval-after-load 'xref
    (my/navigation--advise 'xref-find-definitions))

  ;; Consult。
  (with-eval-after-load 'consult
    (dolist (command '(consult-buffer
                       consult-recent-file
                       consult-bookmark
                       consult-line
                       consult-outline
                       consult-goto-line))
      (my/navigation--advise command)))

  ;; Avy。
  (with-eval-after-load 'avy
    (my/navigation--advise 'avy-goto-char-timer))

  ;; Org Agenda の RET で元項目へ移動する操作。
  (with-eval-after-load 'org-agenda
    (my/navigation--advise 'org-agenda-switch-to)))


(defun my/browsing-history-back ()
  "現在の Browsing History で1つ前の位置へ戻る。"
  (interactive)
  ;; 復元中の switch-to-buffer / find-file は新しい移動として記録しない。
  (let ((my/navigation--tracking t)
        (history (browsing-history-current)))
    (if (and history
             (browsing-history-back history))
        t
      (message "戻る履歴がありません")
      nil)))


(defun my/browsing-history-forward ()
  "現在の Browsing History で1つ後の位置へ進む。"
  (interactive)
  ;; 復元中の switch-to-buffer / find-file は新しい移動として記録しない。
  (let ((my/navigation--tracking t)
        (history (browsing-history-current)))
    (if (and history
             (browsing-history-forward history))
        t
      (message "進む履歴がありません")
      nil)))


(provide 'my-navigation)

;;; my-navigation.el ends here
