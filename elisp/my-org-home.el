;;; my-org-home.el --- Org home buffer helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; org-default-notes-file をホーム画面のように開閉する。

;;; Code:

(defvar org-default-notes-file)

(defvar my/org-home--return-buffer nil
  "Org Home を開く前に表示していたバッファ。")


(defun my/org-home--current-p ()
  "現在のバッファが Org Home なら non-nil を返す。"
  (and buffer-file-name
       (equal (expand-file-name buffer-file-name)
              (expand-file-name org-default-notes-file))))


(defun my/org-home-toggle ()
  "Org Home と、開く前のバッファを切り替える。"
  (interactive)
  (if (my/org-home--current-p)
      (let ((return-buffer my/org-home--return-buffer))
        (setq my/org-home--return-buffer nil)
        (if (buffer-live-p return-buffer)
            (switch-to-buffer return-buffer)
          (switch-to-buffer nil)))
    (setq my/org-home--return-buffer (current-buffer))
    (find-file org-default-notes-file)))


(provide 'my-org-home)

;;; my-org-home.el ends here
