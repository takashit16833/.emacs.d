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


(ert-deftest my/terminal-wheel-scroll-lines-maps-fast-count ()
  "連続入力の回数で1・2・4・8・12行へ段階的に増える。"
  (dolist (case '((0 . 1) (1 . 1) (3 . 1)
                  (4 . 2) (6 . 2) (7 . 4) (9 . 4)
                  (10 . 8) (12 . 8) (13 . 12) (30 . 12)))
    (should (= (my/terminal-wheel-scroll-lines (car case))
               (cdr case)))))

(ert-deftest my/terminal-wheel-next-lines-accelerates-sustained-input ()
  "高速イベントが続いて初めて大きなスクロール量になる。"
  (let (my/terminal-wheel-last-time my/terminal-wheel-last-direction
        (my/terminal-wheel-fast-count 0))
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.0) 1))
    (dotimes (i 3)
      (should (= (my/terminal-wheel-next-lines
                  'wheel-up (+ 10.0 (* (1+ i) 0.016))) 1)))
    (dotimes (i 3)
      (should (= (my/terminal-wheel-next-lines
                  'wheel-up (+ 10.0 (* (+ i 4) 0.016))) 2)))
    (dotimes (i 3)
      (should (= (my/terminal-wheel-next-lines
                  'wheel-up (+ 10.0 (* (+ i 7) 0.016))) 4)))
    (dotimes (i 3)
      (should (= (my/terminal-wheel-next-lines
                  'wheel-up (+ 10.0 (* (+ i 10) 0.016))) 8)))
    (should (= (my/terminal-wheel-next-lines 'wheel-up
                                             (+ 10.0 (* 13 0.016))) 12))
    (should (= (my/terminal-wheel-next-lines 'wheel-up
                                             (+ 10.0 (* 14 0.016))) 12))))

(ert-deftest my/terminal-wheel-next-lines-resets-on-direction-or-pause ()
  "向きの変更・50ms以上の間隔・時刻の逆転で1行に戻す。"
  (let (my/terminal-wheel-last-time my/terminal-wheel-last-direction
        (my/terminal-wheel-fast-count 0))
    (dotimes (i 14)
      (my/terminal-wheel-next-lines 'wheel-up (+ 10.0 (* i 0.016))))
    (should (= my/terminal-wheel-fast-count 13))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.224) 1))
    (should (= my/terminal-wheel-fast-count 0))
    (dotimes (i 5)
      (my/terminal-wheel-next-lines 'wheel-down (+ 10.24 (* i 0.016))))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.36) 1))
    (should (= my/terminal-wheel-fast-count 0))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.0) 1))
    (should (= my/terminal-wheel-fast-count 0))))

(ert-deftest my/terminal-wheel-scroll-binds-amount-only-during-call ()
  "ホイールの処理中だけ行数と標準加速の設定を変更する。"
  (let ((mouse-wheel-scroll-amount '(2))
        (mouse-wheel-progressive-speed t)
        my/terminal-wheel-last-time
        my/terminal-wheel-last-direction
        (my/terminal-wheel-fast-count 0)
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
        (my/terminal-wheel-fast-count 10)
        seen)
    (my/terminal-wheel-scroll
     (lambda (event arg)
       (setq seen (list event arg mouse-wheel-scroll-amount
                        mouse-wheel-progressive-speed)))
     'wheel-right nil)
    (should (equal seen '(wheel-right nil (2) t)))
    (should (null my/terminal-wheel-last-time))
    (should (null my/terminal-wheel-last-direction))
    (should (= my/terminal-wheel-fast-count 0))))

;;; my-terminal-test.el ends here
