;;; navigation.el --- Navigation configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; コード、バッファ、Tabなどの移動に関する設定を置く。

;;; Code:

(require 'my-tab-line)

;; Clutchのtab-line移動は元のウィンドウ配置へ復帰させる。
(require 'my-clutch-fullscreen)
(my/clutch-fullscreen-setup)

;; tab-line は use-package の :demand t で読み込む。
;; バイトコンパイル時は関数の定義元を明示する。
(declare-function tab-line-tabs-non-excluded "tab-line")
(declare-function tab-line-switch-to-next-tab "tab-line")
(declare-function tab-line-switch-to-prev-tab "tab-line")


;; タブを切り替える。
(keymap-global-set "C-<prior>" #'tab-bar-switch-to-prev-tab)
(keymap-global-set "C-<next>" #'tab-bar-switch-to-next-tab)


;; タブを並べ替える。
(keymap-global-set "C-S-<prior>" #'tab-bar-move-tab-backward)
(keymap-global-set "C-S-<next>" #'tab-bar-move-tab)


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
   ;; タブ名に余白とfaceを適用する。
   tab-bar-tab-name-format-functions
   '(my/tab-bar-tab-name-padding
     tab-bar-tab-name-format-face
     tab-bar-tab-name-format-mouse-face))
  (tab-bar-mode 1)

  ;; Emacs 31.1/TTY: 起動時に default-frame-alist の tab-bar-lines=0 を
  ;; 再適用すると、Orgファイルを引数にした起動でSegmentation faultを起こす。
  ;; 現在のフレームは変更せず、問題のある既定値だけを除外する。
  ;; 調査結果・再現手順・未確認事項: docs/tty-org-startup-segfault.md
  (setq default-frame-alist
        (assq-delete-all 'tab-bar-lines default-frame-alist)))


(use-package tab-line
  :ensure nil
  :demand t
  :config
  (setq tab-line-separator ""
        tab-line-new-button-show nil
        tab-line-close-button-show nil
        tab-line-tab-name-function #'my/tab-line-tab-name
        tab-line-tab-name-format-function #'my/tab-line-tab-name-format

        ;; タブの状態に応じてfaceを変更する。
        tab-line-tab-face-functions
        '(tab-line-tab-face-modified
          my/tab-line-tab-face-vc-modified
          tab-line-tab-face-special)

        ;; Git状態の変更もtab-lineのキャッシュ判定に含める。
        tab-line-cache-key-function #'my/tab-line-cache-key

        ;; 除外条件を使って tab-line に表示するバッファを絞る。
        tab-line-tabs-window-buffers-filter-function
        #'tab-line-tabs-non-excluded

        ;; *...* バッファを除外し、Clutch・Haskell REPL・jq Playgroundは表示する。
        ;; Magit / Dired バッファではtab-lineを表示しない。
        tab-line-exclude-buffers my/tab-line-exclude-condition
        tab-line-tabs-function
        'my/tab-line-tabs-bufferlo-buffers)
  (global-tab-line-mode 1))


;; 通常は標準tab-line切り替え。Clutchからの巡回では、先に
;; tab-lineの順序から移動先を決め、編集画面と選択ペインを復元する。
(global-set-key (kbd "C-<tab>") #'my/clutch-fullscreen-tab-line-next)
(global-set-key (kbd "C-S-<tab>") #'my/clutch-fullscreen-tab-line-prev)


;; フレーム・タブローカル機能
(use-package bufferlo
  :ensure t
  :demand t
  :init
  (setq bufferlo-prefer-local-buffers 'tabs
        bufferlo-hidden-buffers '("\\`magit"))
  :bind
  (("C-x b" . bufferlo-switch-to-buffer)
   ("C-x K" . bufferlo-remove)
   ("C-x k" . bufferlo-bury))
  :config
  (bufferlo-mode 1))


;; 表示中の文字へジャンプする。
(use-package avy
  :ensure t
  :bind ("C-;" . avy-goto-char-timer)
  :custom
  (avy-keys '(?o ?t ?a ?n ?i ?s ?e ?h)))


;; ブラウザのような戻る・進む履歴を提供する。
(use-package browsing-history
  :vc (:url "https://github.com/takashit16833/emacs-browsing-history.git"
       :rev :newest)
  :custom
  ;; Tab ごとに独立した履歴を持つ。
  (browsing-history-scope 'tab)
  ;; 各 Tab で最大100地点まで履歴を保持する。
  (browsing-history-max-size 100))


(require 'my-navigation)


;; Browsing History に移動を記録する。
(my/navigation-setup)


;; Browsing History を戻る・進む。
(keymap-global-set "s-[" #'my/browsing-history-back)
(keymap-global-set "s-]" #'my/browsing-history-forward)


(require 'my-tab-routing)


(use-package tab-router
  :vc (:url "https://github.com/takashit16833/emacs-tab-router.git"
       :rev :newest)
  :custom
  (tab-router-functions
   '(my/route-org
     my/route-document
     my/route-project))
  :config
  (tab-router-mode 1))


;;; navigation.el ends here
