;;; my-theme.el --- Shared Retro theme selection -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs と WezTerm で同じテーマ名を共有する。
;; 配色自体はそれぞれのテーマ定義に任せ、ここでは選択と保存だけを扱う。

;;; Code:

(require 'subr-x)

;; 追加するテーマはここへ登録する。右側はテーマ固有の背景反映関数。
(defconst my/theme--themes
  '((retro-hacker-blue . retro-hacker-blue-apply-background)
    (one-dark-blue . one-dark-blue-apply-background))
  "Emacs と WezTerm の両方が対応するテーマ。")

(defconst my/theme--default 'retro-hacker-blue
  "保存済みテーマがない場合に使用するテーマ。")

(defvar my/theme--state-file (expand-file-name "~/.config/retro-theme")
  "WezTerm と共有する、選択中のテーマ名を書いたファイル。")

(defun my/theme--read ()
  "保存済みのテーマ名を返す。未対応・未保存の場合は nil を返す。"
  (when (file-readable-p my/theme--state-file)
    (let* ((name (with-temp-buffer
                   (insert-file-contents my/theme--state-file)
                   (string-trim (buffer-string))))
           (theme (intern-soft name)))
      ;; 以前のテーマ名で保存された選択も引き継ぐ。
      (when (eq theme 'retro-one-dark)
        (setq theme 'one-dark-blue))
      (when (assq theme my/theme--themes)
        theme))))

(defun my/theme--selected ()
  "起動時に使用するテーマを返す。"
  (or (my/theme--read) my/theme--default))

(defun my/theme--activate (theme)
  "THEME を適用する。失敗した場合は以前のテーマを復元する。"
  (let ((background-function (cdr (assq theme my/theme--themes))))
    (unless background-function
      (user-error "Unsupported theme: %s" theme))
    (let ((previous (copy-sequence custom-enabled-themes)))
      (condition-case err
          (progn
            (mapc #'disable-theme previous)
            (load-theme theme t)
            (funcall background-function))
        (error
         (mapc #'disable-theme custom-enabled-themes)
         ;; enable-theme は先頭へ追加するため、元の優先順位で復元する。
         (mapc #'enable-theme (reverse previous))
         (signal (car err) (cdr err)))))))

(defun my/theme--save (theme)
  "THEME の名前を WezTerm と共有するファイルへ保存する。"
  (make-directory (file-name-directory my/theme--state-file) t)
  (with-temp-file my/theme--state-file
    (insert (symbol-name theme) "\n")))

(defun my/theme-select ()
  "テーマを選び、Emacs に適用して WezTerm と選択を共有する。"
  (interactive)
  (let* ((name (completing-read
                "Theme: "
                (mapcar (lambda (entry) (symbol-name (car entry)))
                        my/theme--themes)
                nil t nil nil (symbol-name (my/theme--selected))))
         (theme (intern name)))
    ;; 適用できないテーマを保存して次回の起動を壊さないようにする。
    (my/theme--activate theme)
    (my/theme--save theme)
    (message "Theme: %s" name)))

(provide 'my-theme)
;;; my-theme.el ends here
