;;; my-terminal-test.el --- Terminal input helper tests -*- lexical-binding: t; -*-

;;; Commentary:
;; JIS配列の特殊入力とそれ以外の入力の扱いを確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
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



(ert-deftest my/wezterm-wheel-sequence-encodes-direction-and-lines ()
  "専用の入力列が方向とスクロール量を正しく表す。"
  (should (equal (my/wezterm-wheel-sequence 'up 1) "\e[0;902;1;1~"))
  (should (equal (my/wezterm-wheel-sequence 'down 12) "\e[0;902;2;12~")))

(ert-deftest my/wezterm-wheel-install-decodes-and-dispatches ()
  "入力列が方向と行数に対応したコマンドへ変換される。"
  (let ((input-decode-map (make-sparse-keymap))
        (global-map (make-sparse-keymap))
        seen)
    (my/wezterm-wheel-install)
    (dolist (case '((up . 1) (down . 5) (down . 12)))
      (let* ((direction (car case))
             (lines (cdr case))
             (event (intern (format "my/wezterm-wheel-%s-%d"
                                    direction lines)))
             (sequence (my/wezterm-wheel-sequence direction lines))
             (command (lookup-key global-map (vector event))))
        (should (equal (lookup-key input-decode-map sequence)
                       (vector event)))
        (should (commandp command))
        (cl-letf (((symbol-function 'my/wezterm-wheel-scroll)
                   (lambda (dir n) (setq seen (cons dir n)))))
          (call-interactively command))
        (should (equal seen case))))))

(ert-deftest my/wezterm-wheel-avoids-kkp-prefix-interception ()
  "KKPがCSI 1〜9を捕捉しても専用ホイール入力は影響されない。
KKPの接頭辞登録を模擬し、登録順序の両方を確認する。"
  (dolist (kkp-first '(t nil))
    (let ((input-decode-map (make-sparse-keymap))
          (global-map (make-sparse-keymap)))
      (when kkp-first
        (dotimes (i 9)
          (define-key input-decode-map
                      (format "\e[%d" (1+ i)) #'ignore)))
      (my/wezterm-wheel-install)
      (unless kkp-first
        (dotimes (i 9)
          (define-key input-decode-map
                      (format "\e[%d" (1+ i)) #'ignore)))
      (should (equal (lookup-key input-decode-map
                                 (my/wezterm-wheel-sequence 'up 1))
                     [my/wezterm-wheel-up-1]))
      (should (equal (lookup-key input-decode-map
                                 (my/wezterm-wheel-sequence 'down 12))
                     [my/wezterm-wheel-down-12]))
      (should (eq (lookup-key input-decode-map "\e[9") 'ignore)))))

(ert-deftest my/wezterm-wheel-install-does-not-override-normal-wheel ()
  "標準のホイールイベント用キーは変更しない。"
  (let ((input-decode-map (make-sparse-keymap))
        (global-map (make-sparse-keymap)))
    (define-key global-map [wheel-down] 'ignore)
    (my/wezterm-wheel-install)
    (should (eq (lookup-key global-map [wheel-down]) 'ignore))))

;;; my-terminal-test.el ends here
