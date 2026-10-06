;;; packages.el --- Package management settings -*- lexical-binding: t; -*-
;;; Commentary:
;; パッケージ管理に関する設定を置く。

;;; Code:


;; Emacs標準のパッケージ管理機能を使う。
(require 'package)


;; GNU ELPA / NonGNU ELPA はTUNA mirrorを使用する。
;; MELPAは公式archiveを使用する。
(setopt package-archives
        '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
          ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
          ("melpa" . "https://melpa.org/packages/")))


;;; packages.el ends here
