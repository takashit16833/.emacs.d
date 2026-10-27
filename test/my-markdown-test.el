;;; my-markdown-test.el --- Markdown view toggle tests -*- lexical-binding: t; -*-

;;; Commentary:
;; 閲覧／編集の切り替えで装飾、読み取り専用状態、元テキストを確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-markdown)

(ert-deftest my/markdown-reading-pauses-reveal-without-changing-text ()
  "閲覧時はカーソル追跡を止め、元のMarkdownは変更しない。"
  (with-temp-buffer
    (insert "# Heading\n**bold**\n")
    (set-buffer-modified-p nil)
    (let (calls)
      (cl-letf (((symbol-function 'markdown-indent-mode)
                 (lambda (arg) (push (list 'indent arg) calls)))
                ((symbol-function 'markdown-ts-appear-mode)
                 (lambda (arg)
                   (push (list 'appear arg) calls)
                   (setq-local markdown-ts-hide-markup (> arg 0))))
                ((symbol-function 'markdown-ts-appear-stop)
                 (lambda () (push 'stop calls))))
        (my/markdown-enable-reading)
        (should my/markdown--reading)
        (should buffer-read-only)
        (should markdown-ts-hide-markup)
        (should (equal (nreverse calls)
                       '((indent 1) (appear 1) stop)))
        (should (equal (buffer-string) "# Heading\n**bold**\n"))
        (should-not (buffer-modified-p))))))

(ert-deftest my/markdown-toggle-shows-source-when-editing ()
  "編集時は装飾と視覚上の字下げを止め、実際のMarkdown記法を表示する。"
  (with-temp-buffer
    (insert "## Heading\n*emphasis*\n")
    (set-buffer-modified-p nil)
    (let (calls)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _) t))
                ((symbol-function 'markdown-indent-mode)
                 (lambda (arg) (push (list 'indent arg) calls)))
                ((symbol-function 'markdown-ts-appear-mode)
                 (lambda (arg)
                   (push (list 'appear arg) calls)
                   ;; appearの停止はhide-markupを既定値へ戻す。
                   (setq-local markdown-ts-hide-markup t)))
                ((symbol-function 'markdown-ts-appear-stop)
                 (lambda () (push 'stop calls)))
                ((symbol-function 'markdown-ts-toggle-hide-markup)
                 (lambda ()
                   (push 'show-source calls)
                   (setq-local markdown-ts-hide-markup nil))))
        (my/markdown-enable-reading)
        (setq calls nil)
        (my/markdown-toggle-mode)
        (should-not my/markdown--reading)
        (should-not buffer-read-only)
        (should-not markdown-ts-hide-markup)
        (should (equal (nreverse calls)
                       '((appear -1) (indent -1) show-source)))
        (should (equal (buffer-string) "## Heading\n*emphasis*\n"))
        (should-not (buffer-modified-p))))))

(ert-deftest my/markdown-toggle-preserves-original-read-only ()
  "元から読み取り専用なら編集表示へ切り替えても保護を維持する。"
  (with-temp-buffer
    (read-only-mode 1)
    (cl-letf (((symbol-function 'derived-mode-p) (lambda (&rest _) t))
              ((symbol-function 'markdown-indent-mode) (lambda (&rest _)))
              ((symbol-function 'markdown-ts-appear-mode)
               (lambda (arg) (setq-local markdown-ts-hide-markup (> arg 0))))
              ((symbol-function 'markdown-ts-appear-stop) #'ignore)
              ((symbol-function 'markdown-ts-toggle-hide-markup)
               (lambda () (setq-local markdown-ts-hide-markup nil))))
      (my/markdown-enable-reading)
      (my/markdown-toggle-mode)
      (should buffer-read-only)
      (should-not my/markdown--reading))))

(ert-deftest my/markdown-reading-keeps-already-enabled-renderers ()
  "起動時にhookで有効化した装飾を再初期化しない。"
  (with-temp-buffer
    ;; minor mode の状態はバッファローカル変数として設定する。
    ;; lexical-binding 下の let では実際のモード状態を再現できない。
    (setq-local markdown-indent-mode t
                markdown-ts-appear-mode t)
    (let ((stop-count 0))
      (cl-letf (((symbol-function 'markdown-indent-mode)
                 (lambda (&rest _) (ert-fail "indent reinitialized")))
                ((symbol-function 'markdown-ts-appear-mode)
                 (lambda (&rest _) (ert-fail "appear reinitialized")))
                ((symbol-function 'markdown-ts-appear-stop)
                 (lambda () (setq stop-count (1+ stop-count)))))
        (my/markdown-enable-reading)
        (my/markdown-enable-reading)
        (should (= stop-count 1))
        (should buffer-read-only)
        (should my/markdown--reading)))))

(ert-deftest my/markdown-toggle-rejects-non-markdown-buffer ()
  "Markdown以外では他のモードを変更しない。"
  (with-temp-buffer
    (should-error (my/markdown-toggle-mode) :type 'user-error)
    (should-not my/markdown--reading)))


(ert-deftest my/markdown-reading-restores-visual-line-mode ()
  "閲覧中だけ折り返し、編集に戻ると以前の状態に復元する。"
  (dolist (original '(nil t))
    (with-temp-buffer
      (visual-line-mode (if original 1 -1))
      (cl-letf (((symbol-function 'markdown-indent-mode) #'ignore)
                ((symbol-function 'markdown-ts-appear-mode) #'ignore)
                ((symbol-function 'markdown-ts-appear-stop) #'ignore)
                ((symbol-function 'markdown-ts-toggle-hide-markup) #'ignore)
                ((symbol-function 'my/centered-text--watch-windows) #'ignore)
                ((symbol-function 'my/centered-text--refresh-windows) #'ignore))
        (my/markdown-enable-reading)
        (should visual-line-mode)
        (my/markdown--enable-editing)
        (should (eq (and visual-line-mode t) original))))))

(ert-deftest my/markdown-quote-wrap-prefix-has-rendered-marker ()
  "引用の折り返し記号と背景は通常の引用表示に合わせる。"
  (let ((styled (my/markdown--styled-quote-wrap-prefix "  > " "▎")))
    (should (equal styled "  ▎ "))
    (should (eq (get-text-property 0 'face styled)
                'markdown-ts-block-quote))
    (should (equal (get-text-property 2 'face styled)
                   '(markdown-ts-appear-block-quote-marker
                     markdown-ts-block-quote)))
    (should (eq (get-text-property 3 'face styled)
                'markdown-ts-block-quote))))

(ert-deftest my/markdown-quote-wrap-prefix-leaves-other-prefixes ()
  "リストや通常のインデントは変更しない。"
  (should (equal (my/markdown--styled-quote-wrap-prefix "    " "▎")
                 "    "))
  (should (equal (my/markdown--styled-quote-wrap-prefix "  > " nil)
                 "  > ")))

(ert-deftest my/markdown-quote-wrap-advice-only-while-rendering ()
  "Markdown の装飾中だけ、生成された引用行の折り返しを補正する。"
  (dolist (active '(nil t))
    (with-temp-buffer
      (insert "> example line\n")
      (goto-char (point-min))
      ;; 本来のメジャーモード判定とバッファローカルな minor mode 状態を再現。
      ;; lexical-binding の let と derived-mode-p の差し替えに依存しない。
      (setq-local major-mode 'markdown-ts-mode
                  markdown-ts-appear-mode active
                  markdown-ts-appear-block-quote-marker "▎")
      (should (derived-mode-p 'markdown-ts-mode))
      (my/markdown--style-quote-wrap
       (lambda (_level _indentation wrap)
         (put-text-property (point) (1+ (point)) 'wrap-prefix wrap)
         (forward-line))
       0 0 "> ")
      (let ((prefix (get-text-property (point-min) 'wrap-prefix)))
        (should (equal prefix (if active "▎ " "> "))))
      (should (equal (buffer-string) "> example line\n")))))

;;; my-markdown-test.el ends here
