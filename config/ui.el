;;; ui.el --- User interface configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Emacs の表示と見た目に関する設定を置く。

;;; Code:


(require 'ui)


;; 画面: 上部のメニューバーを隠す（下部のモードラインは残す）。
(menu-bar-mode -1)


;; すべてのバッファで行を折り返す。
(setq-default truncate-lines nil)
(setq truncate-partial-width-windows nil)


;; 折り返し位置の「\」を空白に置き換える。
(require 'disp-table)
(set-display-table-slot standard-display-table 'wrap ?\s)


;; ウィンドウの境界線を細い縦棒にする。
(set-display-table-slot standard-display-table 'vertical-border ?│)


;; ファイル種別に応じたアイコンを取得する。
(use-package nerd-icons
  :ensure t
  :commands nerd-icons-icon-for-file)


;; 最強のカラーテーマ
(use-package retro-hacker-blue-theme
  :vc (:url "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git"
       :rev :newest)
  :no-require t
  :init
  (setq retro-hacker-blue-transparent-background t)
  :config
  (load-theme 'retro-hacker-blue t)
  (retro-hacker-blue-apply-background))


;; 軽量なモードラインを使用する。
(use-package mood-line
  :ensure t
  :custom
  ;; Fira Code向けの記号セットを使用する。
  (mood-line-glyph-alist mood-line-glyphs-fira-code)
  :config
  ;; モードラインの左右に表示する情報と、その間隔を定義する。
  (setq mood-line-format
        (mood-line-defformat
         ;; モードライン全体の左右余白を追加しない。
         :padding ""
         ;; 左側に表示する情報。
         :left
         (;; モーダル編集状態。
          ((mood-line-segment-modal)                  . " ")
          ;; バッファの変更・読み取り専用などの状態。
          ((or (mood-line-segment-buffer-status) " ") . " ")
          ;; 開いているファイルのアイコン。
          ((my/mood-line-segment-file-icon)           . " ")
          ;; バッファ名。
          ((mood-line-segment-buffer-name)            . "  ")
          ;; 検索結果の現在位置と件数。
          ((mood-line-segment-anzu)                   . "  ")
          ;; multiple-cursorsの状態。
          ((mood-line-segment-multiple-cursors)       . "  ")
          ;; カーソルの行・列位置。
          ((mood-line-segment-cursor-position)        . " ")
          ;; バッファ内のスクロール位置。
          (mood-line-segment-scroll))
         ;; 右側に表示する情報。
         :right
         (;; Gitなどのバージョン管理情報。
          ((mood-line-segment-vc)         . "  ")
          ;; 現在のmajor mode。
          ((mood-line-segment-major-mode) . "  ")
          ;; Emacsや各modeが追加する補助情報。
          ((mood-line-segment-misc-info)  . "  ")
          ;; Flymakeなどの診断状態。
          ((mood-line-segment-checker)    . "  ")
          ;; 実行中の外部プロセス情報。
          ((mood-line-segment-process)    . "  "))))
  (mood-line-mode))


;; フレーム上部にタブバーを表示する。
(use-package tab-bar
  :ensure nil
  :demand t
  :config
  (setq
   ;; 新しいタブは*scratch*をデフォルトにする。
   tab-bar-new-tab-choice "*scratch*"
   ;; タブが2個以上のときだけ表示する。
   tab-bar-show 1
   ;; タブ幅を自動調整しない。
   tab-bar-auto-width nil
   ;; 数字キーによるタブ操作だけ標準キーバインドを有効にする。
   tab-bar-define-keys 'numeric
   ;; タブ一覧を右寄せして表示する。
   tab-bar-format '(tab-bar-format-align-right
                    tab-bar-format-tabs)
   ;; タブ同士の区切りを空白にする。
   tab-bar-separator " "
   ;; タブ番号のヒントを表示しない。
   tab-bar-tab-hints nil
   ;; 閉じるボタンを表示しない。
   tab-bar-close-button-show nil
   ;; 新規タブボタンを表示しない。
   tab-bar-new-button-show nil
   ;; タブ名に余白とfaceを適用する。
   tab-bar-tab-name-format-functions
   '(my/tab-bar-tab-name-padding
     tab-bar-tab-name-format-face
     tab-bar-tab-name-format-mouse-face))
  (tab-bar-mode 1))


(use-package tab-line
  :ensure nil
  :demand t
  :config
  (setq tab-line-separator ""
        tab-line-new-button-show nil
        tab-line-close-button-show nil
        tab-line-tab-name-function #'my/tab-line-tab-name
        tab-line-tab-name-format-function #'my/tab-line-tab-name-format
        ;; 除外条件を使って tab-line に表示するバッファを絞る。
        tab-line-tabs-window-buffers-filter-function
        #'tab-line-tabs-non-excluded
        ;; *Messages* などの *...* バッファ、
        ;; Magit 系バッファ、Dired バッファを除外する。
        tab-line-exclude-buffers
        '(or "^\\*.*\\*$"
             (derived-mode . magit-mode)
	     (derived-mode . dired-mode)))
  (global-tab-line-mode 1))


;; アクティブなtab-lineの切り替え
(global-set-key (kbd "C-<tab>") #'tab-line-switch-to-next-tab)
(global-set-key (kbd "C-S-<tab>") #'tab-line-switch-to-prev-tab)


;; 括弧の色分け
(use-package rainbow-delimiters
  :ensure t
  :hook
  (prog-mode . rainbow-delimiters-mode))


;;; ui.el ends here
