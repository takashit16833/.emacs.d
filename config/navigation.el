;;; navigation.el --- Navigation configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; ファイルやコード内の移動に関する設定を置く。

;;; Code:


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


;;; navigation.el ends here
