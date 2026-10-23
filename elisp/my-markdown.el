;;; my-markdown.el --- Markdown reading and editing -*- lexical-binding: t; -*-

;;; Commentary:
;; 閲覧中は装飾を固定し、編集時はMarkdownの元の記法を表示する。

;;; Code:

;; 読み込み前から呼べるよう、遅延読み込みする関数・変数を宣言する。
(defvar markdown-ts-hide-markup)
(defvar markdown-ts-appear-mode)
(defvar markdown-indent-mode)
(declare-function markdown-ts-appear-mode "markdown-ts-appear" (&optional arg))
(declare-function markdown-ts-appear-stop "markdown-ts-appear" ())
(declare-function markdown-indent-mode "markdown-indent-mode" (&optional arg))
(declare-function markdown-ts-toggle-hide-markup "markdown-ts-mode" ())

(defvar-local my/markdown--reading nil
  "Non-nil when the Markdown buffer is in reading mode.")

(defvar-local my/markdown--saved-read-only nil
  "Read-only state before entering Markdown reading mode.")

(defun my/markdown-enable-reading ()
  "Enable fixed, read-only Markdown rendering in the current buffer."
  (unless my/markdown--reading
    (setq-local my/markdown--saved-read-only buffer-read-only)
    ;; 見出しの字下げ、コード枠、表などの装飾は残す。
    (unless (bound-and-true-p markdown-indent-mode)
      (markdown-indent-mode 1))
    (unless (bound-and-true-p markdown-ts-appear-mode)
      (markdown-ts-appear-mode 1))
    ;; カーソル位置で記号を再表示する追跡処理だけ止める。
    (markdown-ts-appear-stop)
    (read-only-mode 1)
    (setq-local my/markdown--reading t)))

(defun my/markdown--enable-editing ()
  "Show unadorned Markdown source in the current buffer."
  (when my/markdown--reading
    (let ((inhibit-read-only t))
      (markdown-ts-appear-mode -1)
      (markdown-indent-mode -1)
      ;; appearを止めるとhide-markupが既定値へ戻るため、明示的に解除。
      (when markdown-ts-hide-markup
        (markdown-ts-toggle-hide-markup)))
    ;; 元から読み取り専用だったバッファは編集可能にしない。
    (read-only-mode (if my/markdown--saved-read-only 1 -1))
    (setq-local my/markdown--reading nil)))

(defun my/markdown-toggle-mode ()
  "Toggle fixed reading and source editing in a Markdown TS buffer.
Reading is read-only; editing shows Markdown markup and preserves an
originally read-only buffer's protection."
  (interactive)
  (unless (derived-mode-p 'markdown-ts-mode)
    (user-error "Not a Markdown TS buffer"))
  (if my/markdown--reading
      (my/markdown--enable-editing)
    (my/markdown-enable-reading))
  (message "Markdown: %s" (if my/markdown--reading "reading" "editing")))

(provide 'my-markdown)

;;; my-markdown.el ends here
