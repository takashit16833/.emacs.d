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


;; ターミナル版Emacsでマウス操作を有効にする。
(unless (display-graphic-p)
  (xterm-mouse-mode 1))


;; スクロール: 上下端の5行手前から追従し、1行移動で画面が大きく跳ねないようにする。
(setq scroll-margin 5
      scroll-conservatively 101)


;;; basic.el ends here
