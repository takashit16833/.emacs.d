;;; my-navigation.el --- Navigation helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Browsing History など、移動に関する独自コマンドを定義する。

;;; Code:

(require 'browsing-history)


(defun my/browsing-history-back ()
  "現在の Browsing History で1つ前の位置へ戻る。"
  (interactive)
  (let ((history (browsing-history-current)))
    (if (and history
             (browsing-history-back history))
        t
      (message "戻る履歴がありません")
      nil)))


(defun my/browsing-history-forward ()
  "現在の Browsing History で1つ後の位置へ進む。"
  (interactive)
  (let ((history (browsing-history-current)))
    (if (and history
             (browsing-history-forward history))
        t
      (message "進む履歴がありません")
      nil)))


(provide 'my-navigation)

;;; my-navigation.el ends here
