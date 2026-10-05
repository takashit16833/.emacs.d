;;; files.el --- File management configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; ファイルとディレクトリの管理に関する設定を置く。

;;; Code:


;; Diredで "." と ".." を表示しない。
(use-package dired-x
  :ensure nil
  :hook
  (dired-mode . dired-omit-mode)
  :custom
  ;; "." と ".." だけを除外する。
  ;; ".git" などの通常の隠しファイルは表示する。
  (dired-omit-files "\\`[.][.]?\\'")
  ;; 拡張子による自動除外は行わない。
  (dired-omit-extensions nil))


;; Diredを拡張したファイルマネージャ。
(use-package dirvish
  :ensure t

  :init
  ;; 通常のDiredもDirvishの表示・機能で扱う。
  (dirvish-override-dired-mode)

  :custom
  ;; 起動時は単一ペインにする。
  ;; `dirvish-layout-toggle' で親ディレクトリとプレビューを表示できる。
  (dirvish-default-layout nil)

  ;; フルレイアウト時もヘッダーを全ペインにまたがって表示する。
  (dirvish-use-header-line 'global)

  ;; フルレイアウト時もフッターを全ペインにまたがって表示する。
  (dirvish-use-mode-line 'global)

  ;; 状態を残す。
  (dirvish-reuse-session t)
  
  ;; 上部:
  ;; 現在のパス / Project / Gitブランチ / ディスク空き容量。
  (dirvish-header-line-format
   '(:left
     (path)
     :right
     (project "  " vc-info "  " free-space)))

  ;; 下部:
  ;; ソート状態 / Omit状態 / symlink先 /
  ;; 権限 / 更新日時 / サイズ / コピー進捗 / 現在位置。
  (dirvish-mode-line-format
   '(:left
     (sort "  " omit "  " symlink)
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

  ;; ディレクトリをプレビューした場合にも
  ;; "." と ".." の非表示状態を引き継ぐ。
  (dirvish-preview-dired-sync-omit t)

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
