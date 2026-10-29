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
  "イベント間隔に応じて1・2・4行へ切り替わる。"
  (should (= (my/terminal-wheel-scroll-lines nil) 1))
  (should (= (my/terminal-wheel-scroll-lines 0.016) 4))
  (should (= (my/terminal-wheel-scroll-lines 0.083) 2))
  (should (= (my/terminal-wheel-scroll-lines 0.304) 1))
  (should (= (my/terminal-wheel-scroll-lines 0.05) 2))
  (should (= (my/terminal-wheel-scroll-lines 0.15) 1)))

(ert-deftest my/terminal-wheel-next-lines-resets-on-direction-change ()
  "向きが変わったときや長時間の間隔では加速を解除する。"
  (let (my/terminal-wheel-last-time my/terminal-wheel-last-direction)
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.0) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-up 10.016) 4))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.032) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.10) 2))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 10.50) 1))
    (should (= (my/terminal-wheel-next-lines 'wheel-down 9.0) 1))))

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
