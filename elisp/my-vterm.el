;;; my-vterm.el --- vterm utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; 現在のタブのディレクトリに対応するvtermを管理する。

;;; Code:

(require 'my-tab-context)
(require 'my-fullscreen-buffer)

(declare-function vterm "vterm" (&optional arg))

(defvar vterm-buffer-name)
(defvar project-current-directory-override)


(defun my/vterm--buffer-name (directory)
  "DIRECTORYに対応するvtermバッファ名を返す。"
  (format "*vterm:%s*"
          (abbreviate-file-name
           (directory-file-name directory))))


(defun my/vterm--directed-display-p ()
  "次のバッファ表示先がwindmoveなどで指定されているなら非nilを返す。"
  ;; windmove-display-* は次のコマンドの間だけこの2変数を設定する。
  ;; この指定があるときは通常の表示動作に任せ、最大化しない。
  (and switch-to-buffer-obey-display-actions
       (car display-buffer-overriding-action)))


(defun my/vterm-toggle ()
  "現在の文脈に対応するvtermを表示・非表示する。
通常はフレーム全体に表示し、再実行で元の分割を復元する。
windmoveなどの表示先指定があれば、その指定を優先する。"
  (interactive)
  (let* ((directory
          (or project-current-directory-override
              (my/tab-context-directory)
              default-directory))
         (buffer-name (my/vterm--buffer-name directory))
         (buffer (get-buffer buffer-name))
         (window (and buffer (get-buffer-window buffer)))
         (saved (my/fullscreen-get 'my/vterm-fullscreen))
         (directed (my/vterm--directed-display-p)))
    (cond
     ((and window (not directed))
      (if (and saved
               (eq (car saved) buffer)
               (one-window-p t)
               (eq window (selected-window)))
          (my/fullscreen-restore 'my/vterm-fullscreen)
        (with-selected-window window
          (previous-buffer)))
      (my/fullscreen-clear 'my/vterm-fullscreen))
     (t
      ;; 分割の保存はタブ単位。異なるタブで同じvtermを使っても混同しない。
      (my/fullscreen-clear 'my/vterm-fullscreen)
      (let ((configuration (unless directed (current-window-configuration)))
            (default-directory directory)
            (vterm-buffer-name buffer-name))
        (vterm)
        (unless directed
          (when-let* ((vterm-buffer (get-buffer buffer-name))
                      (target (get-buffer-window vterm-buffer)))
            (select-window target)
            (unless (one-window-p t)
              (my/fullscreen-enter 'my/vterm-fullscreen
                                   vterm-buffer configuration)))))))))


(provide 'my-vterm)

;;; my-vterm.el ends here
