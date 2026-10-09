;;; my-ui-test.el --- Tests for my-ui -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-ui' のテスト。

;;; Code:

(require 'ert)
(require 'my-ui)


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
  (with-temp-buffer
    (rename-buffer "*jq-playground*" t)
    (should-not (buffer-match-p my/tab-line-exclude-condition
                                (current-buffer)))
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



;;; my-ui-test.el ends here
