;;; database.el --- Database tool configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; PostgreSQL接続とClutchのパッケージを遅延設定する。

;;; Code:

;;; Database --------------------------------------------------------

;; PostgreSQLへEmacs Lispから直接接続する。
(use-package pgsql
  :ensure t
  :defer t)


;; Emacs内でSQLの実行・DBの閲覧を行う。
(use-package clutch
  :ensure t
  :commands clutch-query-console)


;;; database.el ends here

