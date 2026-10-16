;;; my-files.el --- File manager helpers -*- lexical-binding: t; -*-
;;; Commentary:
;; Dirvishなど、ファイル管理UIの補助処理をまとめる。

;;; Code:


(defconst my/dirvish-preview-height-ratio 0.4
  "Dirvishの下側プレビューに使うウィンドウ高さの割合。")


(defun my/dirvish-preview-below (original buffer alist)
  "Dirvishのプレビューを右ではなく下に表示する。
ORIGINAL, BUFFER, ALIST は `dirvish--display-buffer' の引数。"
  (if (and (buffer-live-p buffer)
           (string-prefix-p "*dirvish-preview@" (buffer-name buffer))
           (eq (alist-get 'side alist) 'right))
      (let* ((height (max 4
                          (floor (* (window-total-height)
                                    my/dirvish-preview-height-ratio))))
             (args (copy-tree alist)))
        (setf (alist-get 'side args) 'below
              (alist-get 'window-height args) (- height))
        (funcall original buffer args))
    (funcall original buffer alist)))


(provide 'my-files)


;;; my-files.el ends here
