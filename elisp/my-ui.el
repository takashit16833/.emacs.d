;;; my-ui.el --- Shared UI helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; 見た目の設定関数をまとめる。

;;; Code:

;;; nerd font -------------------------------------------------------

(defvar-local my/file-icon-cache nil
  "現在のバッファのファイルアイコンをキャッシュする。")


(defun my/file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (when buffer-file-name
    (if (equal (car-safe my/file-icon-cache)
               buffer-file-name)
        (cdr my/file-icon-cache)
      ;; ファイル種別ごとの色を使わず、表示先の文字色を継承する。
      (let* ((nerd-icons-color-icons nil)
             (icon (nerd-icons-icon-for-file buffer-file-name)))
        (setq my/file-icon-cache
              (cons buffer-file-name icon))
        icon))))


;;; mood-line -------------------------------------------------------

(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (my/file-icon))


;;; corfu -----------------------------------------------------------

(defun my/corfu-offset-tty-popup (original frame x y width height)
  "TTYのCorfu候補を右へ1文字、下へ1行ずらす。"
  (if (and (not (display-graphic-p))
           (string= (buffer-name) " *corfu*"))
      (funcall original
               frame
               (+ x (default-font-width))
               (+ y (default-line-height))
               width
               height)
    (funcall original frame x y width height)))


(provide 'my-ui)


;;; my-ui.el ends here
