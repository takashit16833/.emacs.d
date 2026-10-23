;;; appearance.el --- Appearance configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs の表示と見た目に関する設定を置く。

;;; Code:

;; テーマ本体は後から読み込むため、設定変数だけ先に宣言する。
(defvar retro-hacker-blue-transparent-background)
(defvar retro-hacker-blue-foreground)
(defvar one-dark-blue-transparent-background)

(require 'my-ui)


;; 画面: 上部のメニューバーを隠す（下部のモードラインは残す）。
(menu-bar-mode -1)


;; すべてのバッファで行を折り返す。
(setq-default truncate-lines nil)
(setq truncate-partial-width-windows nil)


;; 折り返し位置の「\」「$」を空白に置き換える。
(require 'disp-table)
(set-display-table-slot standard-display-table 'wrap ?\s)
(set-display-table-slot standard-display-table 'truncation ?\s)

;; 行番号がある場合はウィンドウの境界線を隠す。
(set-display-table-slot standard-display-table 'vertical-border ?│)

(add-hook 'display-line-numbers-mode-hook #'my/update-vertical-border)


;; 編集用バッファで行番号を表示する。
;; Org / Markdown は本文の読みやすさを優先し、左端の行番号を省く。
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'my/display-line-numbers-for-text)
(setq-default display-line-numbers-width 3)


;; ファイル種別に応じたアイコンを取得する。
(use-package nerd-icons
  :ensure t
  :commands nerd-icons-icon-for-file)


;; 2つのテーマを登録する。配色はテーマ本体へ置き、選択は my-theme に任せる。
(use-package retro-hacker-blue-theme
  :vc (:url "https://github.com/takashit16833/emacs-retro-hacker-blue-theme.git"
	    :rev :newest)
  :no-require t
  :init
  (setq retro-hacker-blue-transparent-background nil))

(use-package one-dark-blue-theme
  :vc (:url "https://github.com/takashit16833/emacs-one-dark-blue-theme.git"
	    :rev :newest)
  :no-require t
  :init
  (setq one-dark-blue-transparent-background nil))

;; 色分けの試用設定。Retro Hacker Blue のテーマ本体は変更しない。
(defun my/appearance-retro-syntax-faces (theme)
  "THEME が Retro Hacker Blue なら、試用中の構文色を適用する。"
  (when (eq theme 'retro-hacker-blue)
    ;; 型名の紫はテーマの基本文字色へ。
    (set-face-attribute 'font-lock-type-face nil
                        :foreground retro-hacker-blue-foreground)
    ;; 型宣言の関数名などは fg-pale で太字にする。
    (set-face-attribute 'font-lock-doc-markup-face nil
                        :foreground (face-attribute
                                     'font-lock-string-face :foreground nil t)
                        :weight 'bold)))

(add-hook 'enable-theme-functions #'my/appearance-retro-syntax-faces)


;; WezTerm と共有した前回の選択を起動時に復元する。
(require 'my-theme)
(my/theme--activate (my/theme--selected))


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


;;; appearance.el ends here
