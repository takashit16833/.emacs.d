;;; my-haskell-simple-indent.el --- Lightweight Haskell indentation -*- lexical-binding: t; -*-

;;; Commentary:
;; VS Code の Haskell 拡張と同じ考え方で、入力中の次の行だけを軽く整える。
;; HLS、Fourmolu、Tree-sitter は呼ばず、直前行の末尾だけを確認する。
;; 完成したコード全体の整形は保存時の Fourmolu に任せる。

;;; Code:

(require 'electric)

(defgroup my-haskell-simple-indent nil
  "Lightweight indentation while editing Haskell."
  :group 'languages)

(defcustom my-haskell-simple-indent-offset 2
  "Haskell のインデントを1段深くするときの幅。"
  :type 'natnum)

(defun my-haskell-simple-indent--increase-p (text)
  "TEXT の次の行を1段深くするなら non-nil を返す。"
  (let ((if-position (string-match "\\_<if\\_>" text)))
    (or (and if-position
             (not (string-match "\\_<then\\_>" text if-position)))
        (string-match-p
         "\\_<\\(?:then\\|else\\|m?do\\|of\\|let\\|in\\|where\\)\\_>[ \t]*\\'"
         text)
        (string-match-p "\\(?:=\\|->\\|>>=\\|>=>\\|=<<\\)[ \t]*\\'" text)
        (string-match-p "\\`[ \t]*data[ \t]+[[:word:]_']+[ \t]*\\'" text))))

(defun my-haskell-simple-indent--target-column ()
  "現在行のインデント先の列を返す。"
  (save-excursion
    (beginning-of-line)
    (if (bobp)
        0
      (forward-line -1)
      (+ (current-indentation)
         (if (my-haskell-simple-indent--increase-p
              (buffer-substring-no-properties
               (line-beginning-position) (line-end-position)))
             my-haskell-simple-indent-offset
           0)))))

(defun my-haskell-simple-indent-line ()
  "空の現在行を入力中の Haskell コードとして軽量にインデントする。"
  (interactive)
  ;; 既存コードの正しさまでは推測しない。RET直後や空行上のTABだけを扱う。
  (when (save-excursion
          (back-to-indentation)
          (eolp))
    (indent-line-to (my-haskell-simple-indent--target-column))
    (back-to-indentation)))

(defun my-haskell-simple-indent-setup ()
  "`haskell-ts-mode' で軽量インデントを使用する。"
  (setq-local indent-line-function #'my-haskell-simple-indent-line)
  ;; RET時に直前行まで再インデントするとHaskellのレイアウトを壊し得る。
  (setq-local electric-indent-inhibit t))

(provide 'my-haskell-simple-indent)

;;; my-haskell-simple-indent.el ends here
