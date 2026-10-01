;;; packages.el --- Package management settings -*- lexical-binding: t; -*-
;;; Commentary:
;; パッケージ管理に関する設定を置く。

;;; Code:


;; Emacs標準のパッケージ管理機能を使う。
(require 'package)


;; GNU ELPA / NonGNU ELPA はEmacs標準で登録されているため、
;; 追加で必要な MELPA だけを登録する。
(add-to-list
 'package-archives
 '("melpa" . "https://melpa.org/packages/")
 t)


;;; packages.el ends here
