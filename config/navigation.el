;;; navigation.el --- Navigation configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; ファイル、コード、ウィンドウ、Tabなどの移動に関する設定を置く。

;;; Code:


;; Tabを切り替える。
(keymap-global-set "M-t" #'tab-bar-switch-to-tab)


;; 次のウィンドウへ移動する。
(keymap-global-set "M-o" #'other-window)


;; Windmove：バッファの表示先指定
(use-package windmove
  :ensure nil
  :bind
  (("C-c <left>"  . windmove-display-left)
   ("C-c <right>" . windmove-display-right)
   ("C-c <up>"    . windmove-display-up)
   ("C-c <down>"  . windmove-display-down)))


;; Diredを拡張したファイルマネージャ。
(use-package dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-attributes
   '(nerd-icons
     subtree-state
     collapse
     file-time
     file-size)))


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


;;; navigation.el ends here
