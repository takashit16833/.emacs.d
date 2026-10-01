;;; ui.el --- Editing commands -*- lexical-binding: t; -*-

;;; Commentary:
;; 見た目の設定関数をまとめる。

;;; Code:


(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (when buffer-file-name
    ;; モードラインではファイル種別ごとの色を使わず、文字色を継承する。
    (let ((nerd-icons-color-icons nil))
      (nerd-icons-icon-for-file buffer-file-name))))


(defun my/tab-bar-tab-name-padding (name _tab _i)
  "タブ名 NAME の左右に余白を加える。"
  (concat "  " name "  "))


(defun my/tab-line-tab-name (buffer &optional _buffers)
  "BUFFER のタブ名を、ファイルアイコン付きで返す。"
  (with-current-buffer buffer
    (if buffer-file-name
        (let ((nerd-icons-color-icons nil))
          (concat
           (nerd-icons-icon-for-file buffer-file-name)
           " "
           (buffer-name buffer)))
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


(provide 'ui)
;;; ui.el ends here
