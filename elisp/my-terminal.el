;;; my-terminal.el --- Terminal input helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 端末のキー入力補正と、ホイールのスクロール量調整。

;;; Code:

(require 'mwheel)

(defun my/kkp-jis-colon (orig input)
  "Option+:をM-:として解釈する。"
  (if (equal (concat input) "59:58:39;3u")
      (kbd "M-:")
    (funcall orig input)))

(defvar my/terminal-wheel-last-time nil)
(defvar my/terminal-wheel-last-direction nil)

(defun my/terminal-wheel-scroll-lines (interval)
  "ホイールイベントの間隔INTERVAL（秒）から移動行数を返す。
実測では速い入力が主に16〜27ms間隔だった。通常の操作を
最速と判定しにくくするため、12行は10ms未満に限定する。"
  (cond
   ((null interval) 1)
   ((< interval 0.010) 12)
   ((< interval 0.015) 8)
   ((< interval 0.035) 4)
   ((< interval 0.075) 2)
   (t 1)))

(defun my/terminal-wheel-next-lines (direction now)
  "DIRECTIONのホイール入力を時刻NOW（秒）に受けたときの移動行数を返す。
同方向の直前イベントとの間隔から、2回目以降はすぐに速度を反映する。
向きが変わったときや時刻が逆転したときは1行から再開する。"
  (let ((interval (and (eq direction my/terminal-wheel-last-direction)
                       my/terminal-wheel-last-time
                       (>= now my/terminal-wheel-last-time)
                       (- now my/terminal-wheel-last-time))))
    (setq my/terminal-wheel-last-direction direction
          my/terminal-wheel-last-time now)
    (my/terminal-wheel-scroll-lines interval)))

(defun my/terminal-wheel-scroll (orig event &optional arg)
  "端末の上下ホイール操作だけ速度に応じて加速し、ORIGへ渡す。
EVENTとARGは標準の `mwheel-scroll' に渡す引数。"
  (let ((direction (event-basic-type event)))
    (if (memq direction '(wheel-up wheel-down mouse-4 mouse-5))
        (let ((mouse-wheel-scroll-amount
               (list (my/terminal-wheel-next-lines direction (float-time))))
              (mouse-wheel-progressive-speed nil))
          (funcall orig event arg))
      ;; 左右スクロールは変更せず、上下スクロールの連続判定をリセットする。
      (setq my/terminal-wheel-last-direction nil
            my/terminal-wheel-last-time nil)
      (funcall orig event arg))))

(provide 'my-terminal)

;;; my-terminal.el ends here
