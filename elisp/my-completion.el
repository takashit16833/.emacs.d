;;; my-completion.el --- Buffer word and LSP completion -*- lexical-binding: t; -*-
;;; Commentary:
;; 普段はバッファ内の単語を後段のCAPFとして使用する。
;; LSP有効時だけLSPと単語の候補をCapeで同じ一覧へ統合する。

;;; Code:

(autoload 'dabbrev-capf "dabbrev")
(declare-function cape-wrap-super "cape" (&rest capfs))
(declare-function cape-wrap-passthrough "cape" (capf))
(declare-function cape-wrap-properties "cape" (capf &rest properties))
(declare-function cape-wrap-predicate "cape" (capf predicate))

(defun my/dabbrev-capf ()
  "単語・シンボルの直後だけdabbrevで補完する。"
  ;; 標準のdabbrev-capfは空白の直後でも「k results」などを補完できる。
  ;; コード補完では単語・シンボルだけを対象にする。
  (when (and (> (point) (point-min))
             (memq (char-syntax (char-before)) '(?w ?_)))
    (when-let* ((capf (dabbrev-capf)))
      ;; 単語補完のkindを明示し、CorfuにTextアイコンを表示させる。
      ;; Capeで統合した場合も候補ごとにこのkindが引き継がれる。
      (append capf (list :company-kind (lambda (_) 'text))))))

(defun my/dabbrev-completion-setup ()
  "既存のCAPFを優先し、dabbrevをバッファの末尾へ追加する。"
  (add-hook 'completion-at-point-functions #'my/dabbrev-capf t t))

(defvar-local my/lsp-dabbrev-source-capf nil
  "統合前のLSP CAPF。Haskellの場合は専用CAPFを保持する。")

(defun my/lsp-dabbrev--track-candidates (capf names)
  "CAPFの候補名をNAMESへ記録しながら、元の補完結果を返す。"
  (pcase (funcall capf)
    (`(,beg ,end ,table . ,props)
     `(,beg ,end
       ,(lambda (str pred action)
          (let ((result (complete-with-action action table str pred)))
            (when (eq action t)
              (clrhash names)
              (dolist (candidate result)
                (puthash (substring-no-properties candidate) t names)))
            result))
       ,@props))))

(defun my/lsp-dabbrev-capf ()
  "元のLSP補完を維持し、同名のdabbrev候補だけを除外して統合する。"
  (when my/lsp-dabbrev-source-capf
    (let ((lsp-names (make-hash-table :test #'equal)))
      (cape-wrap-properties
       (lambda ()
         (cape-wrap-super
          (lambda ()
            ;; Capeは先にLSP候補を取得する。既存の取得結果を記録し、
            ;; 重複判定のためにLSPへ再問い合わせしない。
            (my/lsp-dabbrev--track-candidates
             (lambda ()
               ;; サーバーの候補をprefixで再フィルタしない。
               (cape-wrap-passthrough my/lsp-dabbrev-source-capf))
             lsp-names))
          (lambda ()
            ;; dabbrevだけをフィルタする。LSP同士の同名候補は残す。
            (cape-wrap-predicate
             #'my/dabbrev-capf
             (lambda (candidate)
               (not (gethash (substring-no-properties candidate)
                             lsp-names)))))))
       ;; Capeの合成カテゴリでlsp-passthroughが失われないようにする。
       :category 'lsp-capf))))

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
