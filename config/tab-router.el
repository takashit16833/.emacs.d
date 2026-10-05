;;; tab-router.el --- Tab routing configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; ファイルの表示先 Tab に関する設定を置く。

;;; Code:


(use-package tab-router
  :vc (:url "https://github.com/takashit16833/emacs-tab-router.git"
	    :rev :newest)
  :config
  (tab-router-mode 1))


;;; tab-router.el ends here
