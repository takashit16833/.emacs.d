;;; my-terminal.el --- Terminal input helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 端末のキー入力補正と、WezTermからのスクロール量を受け取る試験処理。

;;; Code:

(defun my/kkp-jis-colon (orig input)
  "Option+:をM-:として解釈する。"
  (if (equal (concat input) "59:58:39;3u")
      (kbd "M-:")
    (funcall orig input)))

(defun my/wezterm-wheel-sequence (direction lines)
  "WezTermのDIRECTIONとLINESに対応する端末入力文字列を返す。
方向はup/down、行数は1〜12。
CSIの先頭を0にして、KKPが捕捉するCSI 1〜9の接頭辞を避ける。"
  (format "\e[0;902;%d;%d~" (if (eq direction 'up) 1 2) lines))

(defun my/wezterm-wheel-scroll (direction lines)
  "DIRECTIONにLINES行だけスクロールする。
バッファの端では標準ホイール同様に移動を止める。"
  (condition-case nil
      (if (eq direction 'down)
          (scroll-up lines)
        (scroll-down lines))
    ((beginning-of-buffer end-of-buffer) nil)))

(defun my/wezterm-wheel-install ()
  "WezTermの通常ホイールからの端末入力を登録する。
通常のホイールイベントやキー入力の処理には変更を加えない。"
  (dolist (direction '(up down))
    (dotimes (i 12)
      (let* ((lines (1+ i))
             (dir direction)
             (event (intern (format "my/wezterm-wheel-%s-%d" dir lines))))
        (define-key input-decode-map
                    (my/wezterm-wheel-sequence dir lines)
                    (vector event))
        (define-key global-map (vector event)
                    (lambda ()
                      (interactive)
                      (my/wezterm-wheel-scroll dir lines)))))))

(provide 'my-terminal)

;;; my-terminal.el ends here
