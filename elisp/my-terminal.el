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
  "直前の同方向イベントとの間隔INTERVAL（秒）から移動行数を返す。
実測で速い操作は主に16〜27ms、遅い操作は主に数百msだった。
通常の操作が最大速度になりにくいよう、最速の境界を20msにする。"
  (cond
   ((null interval) 1)
   ((< interval 0.02) 8)
   ((< interval 0.05) 4)
   ((< interval 0.15) 2)
   (t 1)))

(defun my/terminal-wheel-next-lines (direction now)
  "DIRECTIONのホイール入力を時刻NOW（秒）に受けたときの移動行数を返す。
前回と逆方向の場合や時間が逆転した場合は加速をリセットする。"
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
