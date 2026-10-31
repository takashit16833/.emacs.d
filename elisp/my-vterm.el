;;; my-vterm.el --- vterm utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; 現在のタブのディレクトリに対応するvtermを管理する。
;; vterm分割中も、編集画面との往復で双方の配置を保つ。

;;; Code:

(require 'my-tab-context)
(require 'my-fullscreen-buffer)
(require 'my-tab-line)
(require 'seq)

(declare-function vterm "vterm" (&optional arg))

(defvar vterm-buffer-name)
(defvar project-current-directory-override)

(defvar tab-line-tabs-function)

(defvar-local my/vterm-tab-line-group nil
  "同じtab-lineに並べるvtermのグループ。")


(defun my/vterm-tab-line-tabs ()
  "現在のvtermと同じグループのvtermを、安定した順番で返す。"
  (let* ((group (or my/vterm-tab-line-group (current-buffer)))
         (tab (my/fullscreen--tab))
         (orders (alist-get 'my/vterm-tab-line-orders (cdr tab)))
         (buffers
          (seq-filter
           (lambda (buffer)
             (with-current-buffer buffer
               (and (derived-mode-p 'vterm-mode)
                    (equal (or my/vterm-tab-line-group buffer) group))))
           (buffer-list)))
         (ordered (my/tab-line--stable-buffer-order
                   (alist-get group orders nil nil #'equal)
                   buffers)))
    ;; tab-barタブごと、vtermグループごとに並び順を保持する。
    (setf (alist-get group orders nil nil #'equal) ordered)
    (setf (alist-get 'my/vterm-tab-line-orders (cdr tab)) orders)
    ordered))


(defun my/vterm-tab-line-setup ()
  "vtermでは編集バッファと分離したtab-lineを使用する。"
  (setq-local tab-line-tabs-function #'my/vterm-tab-line-tabs))



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


(defun my/vterm--save-layout ()
  "生存中のvtermだけを残して、現在のタブに表示配置を保存する。"
  (let ((windows (window-list))
        vterm-windows
        seen-buffers)
    (dolist (window windows)
      (let ((buffer (window-buffer window)))
        (with-current-buffer buffer
          (when (and (derived-mode-p 'vterm-mode)
                     (not (memq buffer seen-buffers)))
            (push buffer seen-buffers)
            (push window vterm-windows)))))
    (if (not vterm-windows)
        (my/fullscreen-clear 'my/vterm-layout)
      (let ((target (if (memq (selected-window) vterm-windows)
                        (selected-window)
                      (car vterm-windows))))
        ;; 終了したvtermの代わりに表示されたバッファや重複表示を除去する。
        (dolist (window windows)
          (unless (memq window vterm-windows)
            (delete-window window)))
        (select-window target)
        (setf (alist-get 'my/vterm-layout (cdr (my/fullscreen--tab)))
              (cons (window-buffer target) (current-window-configuration)))))))

(defun my/vterm-split ()
  "現在のvtermを自動的な方向に分割し、新しいvtermを起動する。"
  (interactive)
  (unless (derived-mode-p 'vterm-mode)
    (user-error "vtermバッファで実行してください"))
  (let* ((source (current-buffer))
         (group (or my/vterm-tab-line-group source))
         (saved (my/fullscreen-get 'my/vterm-fullscreen))
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
          (let ((created (vterm '(4))))
            (with-current-buffer source
              (setq-local my/vterm-tab-line-group group))
            (with-current-buffer created
              (setq-local my/vterm-tab-line-group group))))
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
         (layout (my/fullscreen-get 'my/vterm-layout))
         (directed (my/vterm--directed-display-p)))
    (cond
     ;; 最初のvtermが終了していても、元の編集画面を復元する。
     ((and saved (not directed))
      (my/vterm--save-layout)
      (my/fullscreen-restore 'my/vterm-fullscreen t))
     ((and window (not directed))
      (with-selected-window window
        (previous-buffer))
      (my/fullscreen-clear 'my/vterm-fullscreen))
     ;; 前回のvtermの分割配置を復元する。最初のvtermが終了してもよい。
     ((and (not directed)
           layout
           (buffer-live-p (car layout))
           (window-configuration-p (cdr layout)))
      (let ((configuration (current-window-configuration)))
        (set-window-configuration (cdr layout))
        (setf (alist-get 'my/vterm-fullscreen (cdr (my/fullscreen--tab)))
              (cons (car layout) configuration))))
     (t
      ;; 分割の保存はタブ単位。異なるタブで同じvtermを使っても混同しない。
      (my/fullscreen-clear 'my/vterm-fullscreen)
      (my/fullscreen-clear 'my/vterm-layout)
      (let ((configuration (unless directed (current-window-configuration)))
            (default-directory directory)
            (vterm-buffer-name buffer-name))
        (let ((created (vterm)))
          (with-current-buffer created
            (setq-local my/vterm-tab-line-group buffer-name)))
        (unless directed
          (when-let* ((vterm-buffer (get-buffer buffer-name))
                      (target (get-buffer-window vterm-buffer)))
            (select-window target)
            ;; 単一ウィンドウからの起動でも編集画面の配置を保存する。
            (my/fullscreen-enter 'my/vterm-fullscreen
                                 vterm-buffer configuration))))))))

(provide 'my-vterm)

;;; my-vterm.el ends here
