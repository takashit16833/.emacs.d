;;; files.el --- File management configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; ファイルとディレクトリの管理に関する設定を置く。

;;; Code:


;; "." と ".." は表示せず、それ以外の隠しファイルは表示する。
(use-package dired
  :ensure nil
  :defer t
  :custom
  (dired-listing-switches "-Al"))


;; Diredを拡張したファイルマネージャ。
(use-package dirvish
  :ensure t

  :init
  ;; DirvishをDiredへ統合する。
  ;; 現行Dirvishでは、これをDirvish起動前に有効にしておく必要がある。
  (dirvish-override-dired-mode)

  :custom
  ;; 起動時は単一ペインにする。
  ;; `dirvish-layout-toggle' で親ディレクトリとプレビューを表示できる。
  (dirvish-default-layout nil)

  ;; フルレイアウト時はヘッダーを全ペインにまたがって表示する。
  (dirvish-use-header-line 'global)

  ;; フルレイアウト時はフッターを全ペインにまたがって表示する。
  (dirvish-use-mode-line 'global)

  ;; TTYでは画像ベースの先頭バーを表示しない。
  (dirvish-mode-line-bar-image-width 0)

  ;; ファイルを開いた場合もqで閉じた場合も、
  ;; 最後のDirvishセッションを次回再利用する。
  (dirvish-reuse-session t)

  ;; 上部:
  ;; 現在のパス / Project / Gitブランチ / ディスク空き容量。
  (dirvish-header-line-format
   '(:left
     (path)
     :right
     (project "  " vc-info "  " free-space)))

  ;; 下部:
  ;; ソート状態 / symlink先 /
  ;; 権限 / 更新日時 / サイズ / コピー進捗 / 現在位置。
  (dirvish-mode-line-format
   '(:left
     (sort "  " symlink)
     :right
     (file-modes "  "
                 file-time "  "
                 file-size "  "
                 yank "  "
                 index)))

  ;; ファイル一覧そのものにも情報を多めに表示する。
  (dirvish-attributes
   '(subtree-state
     nerd-icons
     collapse
     git-msg
     file-modes
     file-time
     file-size))

  :bind
  (:map dirvish-mode-map
        ;; 上の階層へ移動する。
        ("<left>" . dired-up-directory)

        ;; RETと同じく、ファイルを開く / ディレクトリへ入る。
        ("<right>" . dired-find-file)

        ;; ディレクトリをその場でツリー展開する。
        ("TAB" . dirvish-subtree-toggle)

        ;; Dirvishの機能一覧を開く。
        ("?" . dirvish-dispatch)))


;;; files.el ends here
