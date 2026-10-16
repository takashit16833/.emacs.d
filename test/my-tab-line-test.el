;;; my-tab-line-test.el --- Tab-line face tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Git差分のあるタブで、選択状態ごとの文字色を使い分けることを確認する。

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'my-ui)

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

(provide 'my-tab-line-test)
;;; my-tab-line-test.el ends here
