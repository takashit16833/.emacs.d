;;; my-ui.el --- Editing commands -*- lexical-binding: t; -*-

;;; Commentary:
;; 見た目の設定関数をまとめる。

;;; Code:

(require 'seq)


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


(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (my/file-icon))


(defun my/tab-bar-tab-name-padding (name _tab _i)
  "タブ名 NAME の左右に余白を加える。"
  (concat "  " name "  "))


(defun my/tab-line-tab-name (buffer &optional _buffers)
  "BUFFER のタブ名を、ファイルアイコン付きで返す。"
  (with-current-buffer buffer
    (if buffer-file-name
        (concat
         (my/file-icon)
         " "
         (buffer-name buffer))
      (buffer-name buffer))))


(defun my/tab-line-tab-name-format (tab tabs)
  "TAB の左右に余白を加えて表示する。"
  (let* ((formatted (tab-line-tab-name-format-default tab tabs))
         (properties (and (> (length formatted) 0)
                          (text-properties-at 0 formatted)))
         (left-padding (copy-sequence "  "))
         (right-padding (copy-sequence "  ")))
    (when properties
      (add-text-properties 0 (length left-padding)
                           properties left-padding)
      (add-text-properties 0 (length right-padding)
                           properties right-padding))
    (concat left-padding formatted right-padding)))


(defun my/tab-line--stable-buffer-order (old-buffers current-buffers)
  "CURRENT-BUFFERS を OLD-BUFFERS の既存順を維持して並べる。
OLD-BUFFERS にない新しいbufferは末尾へ追加し、
CURRENT-BUFFERS にないbufferは除外する。"
  (let ((existing-buffers
         (seq-filter
          (lambda (buffer)
            (memq buffer current-buffers))
          old-buffers))
        (new-buffers
         (seq-remove
          (lambda (buffer)
            (memq buffer old-buffers))
          current-buffers)))
    (append existing-buffers new-buffers)))


(defun my/tab-line-tabs-bufferlo-buffers ()
  "現在のTabに属するBufferloのbufferを安定した順番で返す。"
  (let* ((window (selected-window))
         (buffers
          (tab-line-tabs-non-excluded
           (seq-filter
            (lambda (buffer)
              ;; " *Minibuf-1*" などの内部bufferは表示しない。
              (not (string-prefix-p " " (buffer-name buffer))))
            (bufferlo-buffer-list))))
         (ordered-buffers
          (my/tab-line--stable-buffer-order
           (window-parameter window 'tab-line-buffers)
           buffers)))
    (set-window-parameter window 'tab-line-buffers ordered-buffers)
    ordered-buffers))


(provide 'my-ui)


;;; my-ui.el ends here
