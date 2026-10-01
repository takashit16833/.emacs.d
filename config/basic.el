;;; basic.el --- Basic Emacs configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Emacs 全体の基本動作を設定する。

;;; Code:

;; 起動時の案内画面を表示しない。
(setq inhibit-startup-screen t)

;; バックアップ: 編集中のファイルの隣に *~ を作らず、キャッシュ配下へまとめる。
(let ((backup-dir (expand-file-name "~/.cache/emacs/backups/")))
  (make-directory backup-dir t)
  (setq make-backup-files t
        backup-directory-alist `(("." . ,backup-dir))))

;; 自動保存: 復旧用ファイルと保存一覧をリポジトリ外のキャッシュにまとめる。
(let ((auto-save-dir (expand-file-name "~/.cache/emacs/auto-save/")))
  (make-directory auto-save-dir t)
  (setq auto-save-file-name-transforms `((".*" ,auto-save-dir t))
        auto-save-list-file-prefix (expand-file-name ".saves-" auto-save-dir)))

;; Emacsのベル音を鳴らさない。
(setq ring-bell-function #'ignore)

;; Undo / Redo: Command（Super）とOption（Meta）のZを割り当てる。
(use-package undo-fu
  :ensure t
  :bind (("s-z" . undo-fu-only-undo)
         ("s-Z" . undo-fu-only-redo)
         ;; 暫定対応: WezTermから届くShift付きのSuperキーを受け付ける。
         ("S-s-z" . undo-fu-only-redo)
         ("M-z" . undo-fu-only-undo)
         ("M-Z" . undo-fu-only-redo)))
;;; basic.el ends here
