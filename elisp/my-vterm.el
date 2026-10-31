;;; my-vterm.el --- vterm utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; 現在のタブのディレクトリに対応するvtermを管理する。
;; vterm分割中も、編集画面との往復で双方の配置を保つ。

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


(defun my/vterm--save-layout (buffer)
  "分割中のvterm配置をBUFFERとともに現在のタブへ保存する。"
  (if (one-window-p t)
      (my/fullscreen-clear 'my/vterm-layout)
    (setf (alist-get 'my/vterm-layout (cdr (my/fullscreen--tab)))
          (cons buffer (current-window-configuration)))))


(defun my/vterm-split ()
  "現在のvtermを自動的な方向に分割し、新しいvtermを起動する。"
  (interactive)
  (unless (derived-mode-p 'vterm-mode)
    (user-error "vtermバッファで実行してください"))
  (let* ((saved (my/fullscreen-get 'my/vterm-fullscreen))
         (primary (and saved (car saved)))
         (name (if (buffer-live-p primary)
                   (buffer-name primary)
                 (buffer-name)))
         (directory default-directory)
         (window (split-window-sensibly)))
    (unless window
      (user-error "ウィンドウを分割できません"))
    (select-window window)
    (condition-case err
        (let ((vterm-buffer-name name)
              (default-directory directory))
          ;; 非数値の引数は、既存バッファを再利用せず新規作成する。
          (vterm '(4)))
      (error
       (when (window-live-p window)
         (delete-window window))
       (signal (car err) (cdr err))))))


(defun my/vterm-toggle ()
  "現在の文脈に対応するvtermを表示・非表示する。
編集画面とvtermの分割配置を、現在のタブ内で保存・復元する。
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
     ;; 分割先のvtermから実行しても、元の編集画面へ戻す。
     ((and saved (not directed)
           (buffer-live-p (car saved))
           (get-buffer-window (car saved))
           (derived-mode-p 'vterm-mode))
      (my/vterm--save-layout (car saved))
      (my/fullscreen-restore 'my/vterm-fullscreen t))
     ((and window (not directed))
      (with-selected-window window
        (previous-buffer))
      (my/fullscreen-clear 'my/vterm-fullscreen))
     (t
      ;; 分割の保存はタブ単位。異なるタブで同じvtermを使っても混同しない。
      (my/fullscreen-clear 'my/vterm-fullscreen)
      (let ((configuration (unless directed (current-window-configuration)))
            (layout (my/fullscreen-get 'my/vterm-layout))
            (default-directory directory)
            (vterm-buffer-name buffer-name))
        (vterm)
        (unless directed
          (when-let* ((vterm-buffer (get-buffer buffer-name))
                      (target (get-buffer-window vterm-buffer)))
            (select-window target)
            ;; 単一ウィンドウからの起動でも編集画面の配置を保存する。
            (my/fullscreen-enter 'my/vterm-fullscreen
                                 vterm-buffer configuration)
            (when (and layout
                       (eq (car layout) vterm-buffer)
                       (window-configuration-p (cdr layout)))
              (set-window-configuration (cdr layout))))))))))


(provide 'my-vterm)

;;; my-vterm.el ends here
