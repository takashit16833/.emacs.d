;;; my-haskell-simple-indent.el --- Lightweight Haskell indentation -*- lexical-binding: t; -*-

;;; Commentary:
;; VS Code の Haskell 拡張と同じ考え方で、入力中の次の行だけを軽く整える。
;; HLS、Fourmolu、Tree-sitter は呼ばず、直近の空でない行から推奨列を決める。
;; 完成したコード全体の整形は保存時の Fourmolu に任せる。

;;; Code:

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

(defun my-haskell-simple-indent--lambda-do-p (text)
  "TEXT が lambda の本体で do を開始していれば non-nil を返す。"
  (and (string-match-p "\\\\.*->" text)
       (string-match-p "\\_<m?do\\_>[ \t]*\\'" text)))

(defun my-haskell-simple-indent--next-column (text indentation)
  "TEXT と INDENTATION から次行の推奨列を返す。"
  (+ indentation
     (* my-haskell-simple-indent-offset
        (+ (if (my-haskell-simple-indent--increase-p text) 1 0)
           (if (my-haskell-simple-indent--lambda-do-p text) 1 0)))))

(defun my-haskell-simple-indent--target-column ()
  "現在行の推奨インデント列を返す。
直前が空行なら、直近の空でない行を基準にする。"
  (save-excursion
    (beginning-of-line)
    (let (found)
      (while (and (not found)
                  (zerop (forward-line -1)))
        (unless (looking-at-p "[ \t]*$")
          (setq found t)))
      (if (not found)
          0
        (my-haskell-simple-indent--next-column
         (buffer-substring-no-properties
          (line-beginning-position) (line-end-position))
         (current-indentation))))))

(defun my-haskell-simple-indent--blank-line-p ()
  "現在行が空白だけなら non-nil を返す。"
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[ \t]*$")))

(defun my-haskell-simple-indent-line ()
  "空の現在行を推奨列へインデントする。"
  (interactive)
  ;; 既存コードは推測で動かさず、入力中の空行だけを扱う。
  (when (my-haskell-simple-indent--blank-line-p)
    (indent-line-to (my-haskell-simple-indent--target-column))
    (back-to-indentation)))

(defun my-haskell-simple-indent-newline ()
  "改行して、次に入力する Haskell の推奨列へ移動する。"
  (interactive)
  (newline)
  (my-haskell-simple-indent-line))

(defun my-haskell-simple-indent-tab ()
  "空行では推奨列、またはその次の1段へ移動する。"
  (interactive)
  (if (not (my-haskell-simple-indent--blank-line-p))
      (indent-for-tab-command)
    (let* ((target (my-haskell-simple-indent--target-column))
           (current (current-indentation))
           (column (if (< current target)
                       target
                     (+ current my-haskell-simple-indent-offset))))
      (indent-line-to column)
      (back-to-indentation))))

(defun my-haskell-simple-indent-setup ()
  "`haskell-ts-mode' で軽量インデントを使用する。"
  (setq-local indent-line-function #'my-haskell-simple-indent-line)
  (keymap-local-set "RET" #'my-haskell-simple-indent-newline)
  (keymap-local-set "TAB" #'my-haskell-simple-indent-tab)
  (keymap-local-set "<tab>" #'my-haskell-simple-indent-tab))

(provide 'my-haskell-simple-indent)

;;; my-haskell-simple-indent.el ends here
