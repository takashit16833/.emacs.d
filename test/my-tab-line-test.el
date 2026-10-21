;;; my-tab-line-test.el --- Tab-line face tests -*- lexical-binding: t; -*-
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


(provide 'my-tab-line-test)
;;; my-tab-line-test.el ends here
