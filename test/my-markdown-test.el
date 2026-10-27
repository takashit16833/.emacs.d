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


(ert-deftest my/markdown-reading-centered-width ()
  "115列より広いときだけ、中央の本文幅を制限する。"
  (should (equal (my/markdown--center-margins 90) '(0 . 0)))
  (should (equal (my/markdown--center-margins 115) '(0 . 0)))
  (should (equal (my/markdown--center-margins 116) '(0 . 1)))
  (should (equal (my/markdown--center-margins 175) '(30 . 30)))
  (should (equal (my/markdown--center-margins 180) '(32 . 33))))

(ert-deftest my/markdown-reading-margins-follow-resize-and-buffer-switch ()
  "再計算時に余白は累積せず、別バッファ表示時は元へ戻る。"
  (with-temp-buffer
    (setq-local my/markdown--reading t)
    (let* ((window (selected-window))
           (view (current-buffer))
           (other (generate-new-buffer " *markdown-layout-other*"))
           (displayed view)
           (total-width 175)
           (margins '(2 . 1))
           (minimum '(4 . 4))
           (layout nil))
      (unwind-protect
          (cl-letf (((symbol-function 'window-buffer)
                     (lambda (_) displayed))
                    ((symbol-function 'window-body-width)
                     (lambda (&rest _)
                       (- total-width
                          (car (my/markdown--normalized-margins margins))
                          (cdr (my/markdown--normalized-margins margins)))))
                    ((symbol-function 'window-margins)
                     (lambda (&rest _) margins))
                    ((symbol-function 'set-window-margins)
                     (lambda (_ left right)
                       (setq margins (cons left right))))
                    ((symbol-function 'window-parameter)
                     (lambda (_ key)
                       (pcase key
                         ('my/markdown--layout layout)
                         ('min-margins minimum))))
                    ((symbol-function 'set-window-parameter)
                     (lambda (_ key value)
                       (pcase key
                         ('my/markdown--layout (setq layout value))
                         ('min-margins (setq minimum value))))))
            (my/markdown--update-window window)
            (should (equal margins '(30 . 30)))
            (should (equal minimum '(0 . 0)))
            (my/markdown--update-window window)
            (should (equal margins '(30 . 30)))
            (setq total-width 130)
            (my/markdown--update-window window)
            (should (equal margins '(7 . 8)))
            (setq displayed other)
            (my/markdown--update-window window)
            (should (equal margins '(2 . 1)))
            (should (equal minimum '(4 . 4)))
            (should-not layout))
        (kill-buffer other)))))

(ert-deftest my/markdown-reading-restores-visual-line-mode ()
  "閲覧中だけ折り返し、編集に戻ると以前の状態に復元する。"
  (dolist (original '(nil t))
    (with-temp-buffer
      (visual-line-mode (if original 1 -1))
      (cl-letf (((symbol-function 'markdown-indent-mode) #'ignore)
                ((symbol-function 'markdown-ts-appear-mode) #'ignore)
                ((symbol-function 'markdown-ts-appear-stop) #'ignore)
                ((symbol-function 'markdown-ts-toggle-hide-markup) #'ignore)
                ((symbol-function 'my/markdown--watch-windows) #'ignore)
                ((symbol-function 'my/markdown--refresh-windows) #'ignore))
        (my/markdown-enable-reading)
        (should visual-line-mode)
        (my/markdown--enable-editing)
        (should (eq (and visual-line-mode t) original))))))

;;; my-markdown-test.el ends here
