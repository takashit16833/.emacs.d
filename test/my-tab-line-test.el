;;; my-tab-line-test.el --- Tab-line tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Tab-lineの並び順、除外条件、Git差分表示を確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-tab-line)

(ert-deftest my/tab-line-vc-modified-selected-faces ()
  "Git差分のあるタブは選択状態に応じて異なるfaceを使う。"
  (with-temp-buffer
    (cl-letf (((symbol-function 'my/tab-line--git-modified-p)
               (lambda (_buffer) t)))
      (should
       (equal (my/tab-line-tab-face-vc-modified
               (current-buffer) nil 'tab-line-tab-current t t)
              '(:inherit (my/tab-line-tab-vc-modified
                          tab-line-tab-current))))
      (should
       (equal (my/tab-line-tab-face-vc-modified
               (current-buffer) nil 'tab-line-tab-inactive t nil)
              '(:inherit (my/tab-line-tab-vc-modified-inactive
                          tab-line-tab-inactive)))))))

(ert-deftest my/tab-line-vc-unmodified-keeps-face ()
  "Git差分のないタブは従来のfaceを維持する。"
  (with-temp-buffer
    (cl-letf (((symbol-function 'my/tab-line--git-modified-p)
               (lambda (_buffer) nil)))
      (should
       (eq (my/tab-line-tab-face-vc-modified
            (current-buffer) nil 'tab-line-tab-inactive t nil)
           'tab-line-tab-inactive)))))


(ert-deftest my/tab-line--stable-buffer-order-keeps-existing-order ()
  "Bufferlo側の順番が変わっても既存のtab-line順を維持すること。"
  (should
   (equal
    (my/tab-line--stable-buffer-order
     '(a b c)
     '(c b a))
    '(a b c))))


(ert-deftest my/tab-line--stable-buffer-order-appends-new-buffers ()
  "新しいbufferは既存のtab-line順の末尾へ追加すること。"
  (should
   (equal
    (my/tab-line--stable-buffer-order
     '(a b)
     '(c b a d))
    '(a b c d))))


(ert-deftest my/tab-line--stable-buffer-order-removes-missing-buffers ()
  "Bufferloから消えたbufferはtab-line順からも除外すること。"
  (should
   (equal
    (my/tab-line--stable-buffer-order
     '(a b c)
     '(c a))
    '(a c))))


(ert-deftest my/tab-line--git-modified-p-uses-magit-modified-cache ()
  "Magitの差分ありキャッシュをVC状態より優先すること。"
  (with-temp-buffer
    (setq buffer-file-name "/tmp/example.el"
          my/tab-line-git-modified-cache 'modified)
    (set-buffer-modified-p nil)
    (should (my/tab-line--git-modified-p (current-buffer)))))


(ert-deftest my/tab-line--git-modified-p-uses-magit-clean-cache ()
  "Magitの差分なしキャッシュをVC状態より優先すること。"
  (with-temp-buffer
    (setq buffer-file-name "/tmp/example.el"
          my/tab-line-git-modified-cache 'clean)
    (set-buffer-modified-p nil)
    (should-not (my/tab-line--git-modified-p (current-buffer)))))


(ert-deftest my/tab-line-exclude-condition-exempts-jq-playground ()
  "*jq-playground* だけを特殊バッファの除外対象から外す。"
  ;; 開いたままのPlaygroundが存在しても、テスト中に編集・終了しない。
  (let* ((existing (get-buffer "*jq-playground*"))
         (buffer (or existing (generate-new-buffer "*jq-playground*"))))
    (unwind-protect
        (should-not (buffer-match-p my/tab-line-exclude-condition buffer))
      (unless existing
        (kill-buffer buffer))))
  (with-temp-buffer
    (rename-buffer "*other-special*" t)
    (should (buffer-match-p my/tab-line-exclude-condition
                            (current-buffer)))
    (rename-buffer "ordinary-json-buffer" t)
    (should-not (buffer-match-p my/tab-line-exclude-condition
                                (current-buffer)))))


(ert-deftest my/tab-line-exclude-condition-preserves-mode-exceptions ()
  "ClutchとHaskell REPLの例外、MagitとDiredの除外を維持する。"
  (dolist (mode '(clutch-mode haskell-ts-inferior-mode))
    (with-temp-buffer
      (rename-buffer "*other-special*" t)
      (setq major-mode mode)
      (should-not (buffer-match-p my/tab-line-exclude-condition
                                  (current-buffer)))))
  (dolist (mode '(magit-mode dired-mode))
    (with-temp-buffer
      (rename-buffer "ordinary-buffer" t)
      (setq major-mode mode)
      (should (buffer-match-p my/tab-line-exclude-condition
                              (current-buffer))))))



(ert-deftest my/tab-line-order-shared-across-split-windows ()
  "同じtab-barタブなら、上下のペインでtab-lineの並び順を共有する。"
  (save-window-excursion
    (let ((a (generate-new-buffer "tab-line-test-a"))
          (b (generate-new-buffer "tab-line-test-b"))
          (c (generate-new-buffer "tab-line-test-c"))
          (tab (list 'current-tab))
          buffer-list-for-test)
      (unwind-protect
          (progn
            (delete-other-windows)
            (let ((lower (split-window-below)))
              (setq buffer-list-for-test (list a b c))
              (cl-letf (((symbol-function 'tab-bar-tabs)
                         (lambda () (list tab)))
                        ((symbol-function 'bufferlo-buffer-list)
                         (lambda (&rest _) buffer-list-for-test))
                        ((symbol-function 'tab-line-tabs-non-excluded)
                         (lambda (buffers) buffers)))
                (should (equal (my/tab-line-tabs-bufferlo-buffers)
                               (list a b c)))
                ;; 反対側のペインではBufferloの提示順を逆転させる。
                ;; それでも表示順は最初のペインと一致する。
                (select-window lower)
                (setq buffer-list-for-test (list c b a))
                (should (equal (my/tab-line-tabs-bufferlo-buffers)
                               (list a b c)))
                (should (equal (alist-get 'my/tab-line-buffers (cdr tab))
                               (list a b c))))))
        (dolist (buffer (list a b c))
          (when (buffer-live-p buffer)
            (kill-buffer buffer)))))))


(ert-deftest my/tab-line-order-is-independent-between-tab-bar-tabs ()
  "tab-barタブが異なる場合はバッファ並び順を共有しない。"
  (let ((a (generate-new-buffer "tab-line-test-a"))
        (b (generate-new-buffer "tab-line-test-b"))
        (tab-a (list 'current-tab))
        (tab-b (list 'current-tab))
        tab
        buffers)
    (unwind-protect
        (progn
          (setq tab tab-a
                buffers (list a b))
          (cl-letf (((symbol-function 'tab-bar-tabs)
                     (lambda () (list tab)))
                    ((symbol-function 'bufferlo-buffer-list)
                     (lambda (&rest _) buffers))
                    ((symbol-function 'tab-line-tabs-non-excluded)
                     (lambda (items) items)))
            (should (equal (my/tab-line-tabs-bufferlo-buffers)
                           (list a b)))
            (setq tab tab-b
                  buffers (list b a))
            (should (equal (my/tab-line-tabs-bufferlo-buffers)
                           (list b a)))
            ;; 元のtab-barタブの順序は変更されない。
            (setq tab tab-a)
            (should (equal (my/tab-line-tabs-bufferlo-buffers)
                           (list a b)))))
      (dolist (buffer (list a b))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))


(provide 'my-tab-line-test)
;;; my-tab-line-test.el ends here
