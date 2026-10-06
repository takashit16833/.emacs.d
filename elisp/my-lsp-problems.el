;;; my-lsp-problems.el --- LSP Problems buffer -*- lexical-binding: t; -*-

;;; Commentary:
;; lsp-modeが保持するworkspace診断を、全文付きの一覧として表示する。

;;; Code:


(defconst my/lsp-problems-buffer-name "*LSP Problems*"
  "LSP診断一覧を表示するバッファ名。")

(defvar-local my/lsp-problems-source-buffer nil
  "LSP診断の取得元バッファ。")

(defvar-local my/lsp-problems-project-root nil
  "LSP診断一覧の表示基準となるプロジェクトルート。")


(defun my/lsp-problems--severity (diagnostic)
  "DIAGNOSTICのseverityに対応するラベルとfaceを返す。"
  (pcase (lsp-get diagnostic :severity)
    (1 (cons "ERROR" 'error))
    (2 (cons "WARNING" 'warning))
    (3 (cons "INFO" 'success))
    (_ (cons "HINT" 'shadow))))


(defun my/lsp-problems--start-position (diagnostic)
  "DIAGNOSTICの開始位置を返す。"
  (let ((range (lsp-get diagnostic :range)))
    (and range
         (lsp-get range :start))))


(defun my/lsp-problems--line (diagnostic)
  "DIAGNOSTICの0始まりの行番号を返す。"
  (let ((start (my/lsp-problems--start-position diagnostic)))
    (or (and start (lsp-get start :line))
        0)))


(defun my/lsp-problems--character (diagnostic)
  "DIAGNOSTICの0始まりの文字位置を返す。"
  (let ((start (my/lsp-problems--start-position diagnostic)))
    (or (and start (lsp-get start :character))
        0)))


(defun my/lsp-problems--collect ()
  "現在のProblemsバッファに対応するLSP診断を取得する。"
  (let ((source my/lsp-problems-source-buffer)
        diagnostics)
    (when (buffer-live-p source)
      (with-current-buffer source
        (maphash
         (lambda (file file-diagnostics)
           (dolist (diagnostic file-diagnostics)
             (push (cons file diagnostic) diagnostics)))
         (lsp-diagnostics t))))
    (sort diagnostics
          (lambda (left right)
            (let ((left-file (car left))
                  (right-file (car right)))
              (if (string= left-file right-file)
                  (< (my/lsp-problems--line (cdr left))
                     (my/lsp-problems--line (cdr right)))
                (string-lessp left-file right-file)))))))


(defun my/lsp-problems--display-file-name (file)
  "FILEをProblemsバッファ用のファイル名にする。"
  (condition-case nil
      (file-relative-name file my/lsp-problems-project-root)
    (error file)))


(defun my/lsp-problems--insert-diagnostic (file diagnostic)
  "FILEのDIAGNOSTICを現在のバッファへ全文表示する。"
  (let* ((severity (my/lsp-problems--severity diagnostic))
         (label (car severity))
         (face (cdr severity))
         (line (1+ (my/lsp-problems--line diagnostic)))
         (character (1+ (my/lsp-problems--character diagnostic)))
         (source (lsp-get diagnostic :source))
         (code (lsp-get diagnostic :code))
         (message (or (lsp-get diagnostic :message) ""))
         (position (my/lsp-problems--start-position diagnostic))
         (start (point)))
    (insert "  "
            (propertize label 'face face)
            (format "  %d:%d" line character))
    (when source
      (insert (format "  [%s]" source)))
    (when code
      (insert (format "  [%s]" code)))
    (insert "\n")
    (dolist (message-line (split-string message "\n" nil))
      (insert "    " message-line "\n"))
    (insert "\n")
    (add-text-properties
     start
     (point)
     (list 'my/lsp-problems-file file
           'my/lsp-problems-position position
           'mouse-face 'highlight
           'help-echo "RET: 診断位置へ移動"))))


(defun my/lsp-problems-refresh ()
  "LSP Problemsバッファを最新の診断内容で更新する。"
  (interactive)
  (when (buffer-live-p my/lsp-problems-source-buffer)
    (let ((inhibit-read-only t)
          (diagnostics (my/lsp-problems--collect))
          current-file)
      (erase-buffer)
      (if diagnostics
          (dolist (entry diagnostics)
            (let ((file (car entry))
                  (diagnostic (cdr entry)))
              (unless (equal file current-file)
                (setq current-file file)
                (insert (propertize
                         (my/lsp-problems--display-file-name file)
                         'face 'bold)
                        "\n"))
              (my/lsp-problems--insert-diagnostic file diagnostic)))
        (insert "診断はありません。\n"))
      (goto-char (point-min)))))


(defun my/lsp-problems-refresh-if-open ()
  "LSP診断更新時、Problemsバッファが開いていれば更新する。"
  (let ((buffer (get-buffer my/lsp-problems-buffer-name)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (my/lsp-problems-refresh)))))


(defun my/lsp-problems--property-at-point (property)
  "現在位置のPROPERTYを返す。"
  (or (get-text-property (point) property)
      (and (> (point) (point-min))
           (get-text-property (1- (point)) property))))


(defun my/lsp-problems-visit ()
  "現在位置の診断へ移動する。"
  (interactive)
  (let ((file (my/lsp-problems--property-at-point 'my/lsp-problems-file))
        (position
         (my/lsp-problems--property-at-point 'my/lsp-problems-position)))
    (unless (and file position)
      (user-error "この位置に診断はありません"))
    (pop-to-buffer (find-file-noselect file))
    (goto-char (lsp--position-to-point position))
    (recenter)))


(defun my/lsp-problems--move (direction)
  "DIRECTION方向の次の診断へ移動する。"
  (let* ((property 'my/lsp-problems-file)
         (limit (if (> direction 0) (point-max) (point-min)))
         (position
          (if (> direction 0)
              (next-single-property-change (point) property nil limit)
            (previous-single-property-change (point) property nil limit))))
    (while (and position
                (/= position limit)
                (not (get-text-property position property)))
      (setq position
            (if (> direction 0)
                (next-single-property-change position property nil limit)
              (previous-single-property-change position property nil limit))))
    (when (and position
               (/= position limit))
      (goto-char position)
      (beginning-of-line))))


(defun my/lsp-problems-next ()
  "次の診断へ移動する。"
  (interactive)
  (my/lsp-problems--move 1))


(defun my/lsp-problems-previous ()
  "前の診断へ移動する。"
  (interactive)
  (my/lsp-problems--move -1))


(define-derived-mode my/lsp-problems-mode special-mode "LSP Problems"
  "LSPのプロジェクト診断を全文表示する。"
  (setq-local truncate-lines nil)
  (setq-local header-line-format
              " RET: jump   g: refresh   n/p: next/previous   q: close"))

(keymap-set my/lsp-problems-mode-map "RET" #'my/lsp-problems-visit)
(keymap-set my/lsp-problems-mode-map "g" #'my/lsp-problems-refresh)
(keymap-set my/lsp-problems-mode-map "n" #'my/lsp-problems-next)
(keymap-set my/lsp-problems-mode-map "p" #'my/lsp-problems-previous)


(defun my/lsp-problems ()
  "現在のLSP workspaceの診断を全文一覧表示する。"
  (interactive)
  (require 'lsp-mode)
  (require 'project)
  (unless (bound-and-true-p lsp-mode)
    (user-error "このバッファではLSPが有効ではありません"))
  (let ((source (current-buffer))
        (root (project-root (project-current t))))
    (pop-to-buffer (get-buffer-create my/lsp-problems-buffer-name))
    (my/lsp-problems-mode)
    (setq-local my/lsp-problems-source-buffer source)
    (setq-local my/lsp-problems-project-root root)
    (my/lsp-problems-refresh)))


(provide 'my-lsp-problems)

;;; my-lsp-problems.el ends here
