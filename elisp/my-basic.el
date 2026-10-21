;;; my-basic.el --- Basic Emacs utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs全体の基本動作に関する独自機能を定義する。
;;
;; 設定値やキーバインドなどは `config/core.el' に置き、
;; ここには独自関数などの実装を置く。

;;; Code:


(defun my/byte-compile-config ()
  "更新された `config/' と `elisp/' のファイルをバイトコンパイルする。"
  (interactive)
  (require 'bytecomp)
  (let ((count 0))
    (dolist (directory '("elisp" "config"))
      (dolist (file (directory-files
                     (expand-file-name directory user-emacs-directory)
                     t "\\.el\\'"))
        (let ((compiled (byte-compile-dest-file file)))
          (when (or (not (file-exists-p compiled))
                    (file-newer-than-file-p file compiled))
            (unless (byte-compile-file file)
              (error "バイトコンパイルに失敗しました: %s" file))
            (setq count (1+ count))))))
    (when (called-interactively-p 'interactive)
      (message "%d個のファイルをバイトコンパイルしました" count))
    count))


(defun my/reload-init-file ()
  "更新された設定をバイトコンパイルし、init.elを再読み込みする。"
  (interactive)
  (condition-case err
      (let ((count (my/byte-compile-config)))
        (load-file (expand-file-name "init.el" user-emacs-directory))
        (message "init.el を再読み込みしました（コンパイル: %dファイル）" count))
    (error
     (message "設定のコンパイルまたは再読み込みに失敗しました: %s" err))))


(provide 'my-basic)

;;; my-basic.el ends here
