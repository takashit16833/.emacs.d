;;; my-terminal-test.el --- Terminal input helper tests -*- lexical-binding: t; -*-

;;; Commentary:
;; JIS配列の特殊入力とホイールスクロールの入力処理を確認する。

;;; Code:

(require 'ert)
(require 'my-terminal)

(ert-deftest my/kkp-jis-colon-translates-option-colon ()
  "Option+:の入力をMeta-:へ変換する。"
  (should (equal
           (my/kkp-jis-colon
            (lambda (_input) (ert-fail "Original should not run"))
            "59:58:39;3u")
           (kbd "M-:"))))

(ert-deftest my/kkp-jis-colon-delegates-other-inputs ()
  "対象外の入力を変更せず、元の関数へ渡す。"
  (let ((input [49 59 51 117])
        seen)
    (should (eq :original
                (my/kkp-jis-colon
                 (lambda (value)
                   (setq seen value)
                   :original)
                 input)))
    (should (eq seen input))))


(ert-deftest my/terminal-wheel-scroll-lines-maps-intervals ()
  "速度に応じて1・2・4・8・12行を返し、判定境界も確認する。"
  (dolist (case '((nil . 1)
                  (0.005 . 12) (0.010 . 8)
                  (0.012 . 8) (0.015 . 4)
                  (0.016 . 4) (0.027 . 4)
                  (0.035 . 2) (0.040 . 2)
                  (0.075 . 1) (0.083 . 1)
                  (0.304 . 1)))
    (should (= (my/terminal-wheel-scroll-lines (car case))
               (cdr case)))))

(ert-deftest my/terminal-wheel-next-lines-reacts-to-second-event ()
  "高速入力は2回目から加速し、入力回数の蓄積を必要としない。"
  (let (my/terminal-wheel-last-time my/terminal-wheel-last-direction)
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.0) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.016) 4))
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.021) 12))
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.033) 8))))

(ert-deftest my/terminal-wheel-next-lines-resets-on-direction-change ()
  "逆方向や時刻逆転では1行に戻し、長い間隔でも低速になる。"
  (let (my/terminal-wheel-last-time my/terminal-wheel-last-direction)
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.0) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.005) 12))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.010) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.314) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.0) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.016) 4))))

(ert-deftest my/terminal-wheel-scroll-binds-amount-only-during-call ()
  "ホイールの処理中だけ行数と標準加速の設定を変更する。"
  (let ((mouse-wheel-scroll-amount '(2))
        (mouse-wheel-progressive-speed t)
        my/terminal-wheel-last-time
        my/terminal-wheel-last-direction
        seen)
    (my/terminal-wheel-scroll
     (lambda (event arg)
       (setq seen (list event arg mouse-wheel-scroll-amount
                        mouse-wheel-progressive-speed)))
     'wheel-down :arg)
    (should (equal seen '(wheel-down :arg (1) nil)))
    (should (equal mouse-wheel-scroll-amount '(2)))
    (should mouse-wheel-progressive-speed)))

(ert-deftest my/terminal-wheel-scroll-preserves-horizontal-input ()
  "左右スクロールは元の処理へそのまま渡す。"
  (let ((mouse-wheel-scroll-amount '(2))
        (mouse-wheel-progressive-speed t)
        (my/terminal-wheel-last-time 10.0)
        (my/terminal-wheel-last-direction 'wheel-down)
        seen)
    (my/terminal-wheel-scroll
     (lambda (event arg)
       (setq seen (list event arg mouse-wheel-scroll-amount
                        mouse-wheel-progressive-speed)))
     'wheel-right nil)
    (should (equal seen '(wheel-right nil (2) t)))
    (should (null my/terminal-wheel-last-time))
    (should (null my/terminal-wheel-last-direction))))

;;; my-terminal-test.el ends here
