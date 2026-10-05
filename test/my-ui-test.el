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


;;; my-ui-test.el ends here
