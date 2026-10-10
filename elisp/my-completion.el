;;; my-completion.el --- Buffer word and LSP completion -*- lexical-binding: t; -*-
;;; Commentary:
;; 普段はバッファ内の単語を後段のCAPFとして使用する。
;; LSP有効時だけLSPと単語の候補をCapeで同じ一覧へ統合する。

;;; Code:

(autoload 'dabbrev-capf "dabbrev")
(declare-function cape-wrap-super "cape" (&rest capfs))
(declare-function cape-wrap-passthrough "cape" (capf))
(declare-function cape-wrap-properties "cape" (capf &rest properties))

(defun my/dabbrev-capf ()
  "単語・シンボルの直後だけdabbrevで補完する。"
  ;; 標準のdabbrev-capfは空白の直後でも「k results」などを補完できる。
  ;; コード補完では単語・シンボルだけを対象にする。
  (when (and (> (point) (point-min))
             (memq (char-syntax (char-before)) '(?w ?_)))
    (when-let* ((capf (dabbrev-capf)))
      ;; バッファ由来の候補をLSPのtext候補と区別して表示する。
      ;; nerd-icons-corfu側でdabbrevにFile Textアイコンを割り当てる。
      (append capf (list :company-kind (lambda (_) 'dabbrev))))))

(defun my/dabbrev-completion-setup ()
  "既存のCAPFを優先し、dabbrevをバッファの末尾へ追加する。"
  (add-hook 'completion-at-point-functions #'my/dabbrev-capf t t))

(defvar-local my/lsp-dabbrev-source-capf nil
  "統合前のLSP CAPF。Haskellの場合は専用CAPFを保持する。")

(defun my/lsp-dabbrev-capf ()
  "元のLSP補完処理を保ったままdabbrev候補を統合する。"
  (when my/lsp-dabbrev-source-capf
    ;; LSPが返した候補をCape内部でprefixフィルタし直さない。
    ;; LSPはserver側のフィルタリングとlsp-passthroughを使っている。
    (cape-wrap-properties
     (lambda ()
       (cape-wrap-super
        (lambda ()
          (cape-wrap-passthrough my/lsp-dabbrev-source-capf))
        #'my/dabbrev-capf))
     ;; Capeの合成カテゴリに置き換わるとlsp-passthroughが外れる。
     ;; 元のLSPカテゴリを戻して候補絞り込み・確定を維持する。
     :category 'lsp-capf)))

(defun my/lsp-dabbrev-completion-setup ()
  "LSP有効時に元のCAPFを候補統合版へ差し替える。"
  (let ((source
         (when (bound-and-true-p lsp-completion-mode)
           (cond
            ((memq #'my/haskell-lsp-completion-at-point
                   completion-at-point-functions)
             #'my/haskell-lsp-completion-at-point)
            ((memq #'lsp-completion-at-point
                   completion-at-point-functions)
             #'lsp-completion-at-point)
            (t my/lsp-dabbrev-source-capf)))))
    (remove-hook 'completion-at-point-functions #'my/lsp-dabbrev-capf t)
    (setq my/lsp-dabbrev-source-capf source)
    (when source
      (remove-hook 'completion-at-point-functions
                   #'my/haskell-lsp-completion-at-point t)
      (remove-hook 'completion-at-point-functions
                   #'lsp-completion-at-point t)
      (add-hook 'completion-at-point-functions #'my/lsp-dabbrev-capf nil t))))

(provide 'my-completion)
;;; my-completion.el ends here
