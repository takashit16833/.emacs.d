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

(defun my-haskell-simple-indent--increase-levels (text)
  "TEXT の次行で増やすインデント段数を返す。"
  (cond
   ;; lambda と do の2段を同じ行で開いた場合。
   ((string-match-p
     "\\\\.*->[ \t]*\\(?:m?do\\)[ \t]*\\'"
     text)
    2)
   ((my-haskell-simple-indent--increase-p text)
    1)
   (t
    0)))

(defun my-haskell-simple-indent--target-column ()
  "現在行のインデント先の列を返す。
直前が空行なら、直近の空でない行を基準にする。"
  (save-excursion
    (beginning-of-line)
    (let (previous-line)
      (while (and (not previous-line)
                  (zerop (forward-line -1)))
        (unless (looking-at-p "[ \t]*$")
          (setq previous-line (point))))
      (if (not previous-line)
          0
        (let ((text (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
          (+ (current-indentation)
             (* (my-haskell-simple-indent--increase-levels text)
                my-haskell-simple-indent-offset)))))))

(defun my-haskell-simple-indent-line ()
  "空の現在行を入力中の Haskell コードとして軽量にインデントする。"
  (interactive)
  ;; 既存コードの正しさまでは推測しない。RET直後や空行上のTABだけを扱う。
  (when (save-excursion
          (back-to-indentation)
          (eolp))
    (let* ((target (my-haskell-simple-indent--target-column))
           (current (current-indentation))
           (column
            (if (and (eq this-command 'indent-for-tab-command)
                     (>= current target))
                (+ current my-haskell-simple-indent-offset)
              target)))
      (indent-line-to column)
      (back-to-indentation))))

(defun my-haskell-simple-indent-setup ()
  "`haskell-ts-mode' で軽量インデントを使用する。"
  (setq-local indent-line-function #'my-haskell-simple-indent-line)
  ;; RET時に直前行まで再インデントするとHaskellのレイアウトを壊し得る。
  (setq-local electric-indent-inhibit t))

(provide 'my-haskell-simple-indent)

;;; my-haskell-simple-indent.el ends here
