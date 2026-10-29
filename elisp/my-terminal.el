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
(defvar my/terminal-wheel-fast-count 0)

(defun my/terminal-wheel-scroll-lines (fast-count)
  "速い入力が連続した回数FAST-COUNTからスクロール行数を返す。
実測では速い操作が約16〜27ms間隔だったため、1回の間隔だけで
最大量にせず、高速入力が続くほど段階的に増やす。"
  (cond
   ((>= fast-count 13) 12)
   ((>= fast-count 10) 8)
   ((>= fast-count 7) 4)
   ((>= fast-count 4) 2)
   (t 1)))

(defun my/terminal-wheel-next-lines (direction now)
  "DIRECTIONのホイール入力を時刻NOW（秒）に受けたときの移動行数を返す。
同じ方向の入力が50ms未満の間隔で続く場合だけ加速する。
間隔が空いたり、向きが変わったりした場合は1行から再開する。"
  (setq my/terminal-wheel-fast-count
        (if (and (eq direction my/terminal-wheel-last-direction)
                 my/terminal-wheel-last-time
                 (>= now my/terminal-wheel-last-time)
                 (< (- now my/terminal-wheel-last-time) 0.05))
            (1+ my/terminal-wheel-fast-count)
          0)
        my/terminal-wheel-last-direction direction
        my/terminal-wheel-last-time now)
  (my/terminal-wheel-scroll-lines my/terminal-wheel-fast-count))

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
            my/terminal-wheel-last-time nil
            my/terminal-wheel-fast-count 0)
      (funcall orig event arg))))

(provide 'my-terminal)

;;; my-terminal.el ends here
