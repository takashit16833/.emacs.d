;;; my-completion.el --- Buffer word completion -*- lexical-binding: t; -*-

;;; Commentary:
;; 通常は既存CAPFの後段にdabbrevを置く。
;; Eglot管理中は両者の候補をCapeで統合し、重複時はEglot側を採用する。
;; Eglotの候補は確定時の追加編集やHLSの自動import用commandを持つため、
;; 文字列だけ同じdabbrev候補に置き換えてはいけない。

;;; Code:

(autoload 'dabbrev-capf "dabbrev")
(defun my/dabbrev-capf ()
  "単語・シンボルの直後だけdabbrevで補完する。"
  ;; 標準のdabbrev-capfは空白の直後でも「k results」などを補完できる。
  ;; コード補完では単語・シンボルだけを対象にする。
  (when (and (> (point) (point-min))
             (memq (char-syntax (char-before)) '(?w ?_)))
    (when-let* ((capf (dabbrev-capf)))
      ;; 単語補完のkindを明示し、CorfuにTextアイコンを表示させる。
      ;; Corfu側でTextの種類として表示できるようにする。
      (append capf (list :company-kind (lambda (_) 'text))))))

(defun my/dabbrev-completion-setup ()
  "既存のCAPFを優先し、dabbrevをバッファの末尾へ追加する。"
  (add-hook 'completion-at-point-functions #'my/dabbrev-capf t t))

(declare-function cape-wrap-super "cape" (&rest capfs))
(declare-function cape-wrap-predicate "cape" (capf predicate))
(declare-function cape-wrap-properties "cape" (capf &rest properties))
(declare-function eglot-managed-p "eglot" ())

(defun my/eglot-dabbrev--track-candidates (capf names)
  "CAPFの候補名をNAMESへ記録し、元の補完結果は変更せず返す。"
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

(defun my/eglot-dabbrev-capf ()
  "Eglotとdabbrevの候補を統合し、同名候補はEglotを優先する。"
  ;; 以前のlsp-modeでも、単にdabbrevをCAPFの末尾に置くだけでは
  ;; HLSとdabbrevの候補を同じ一覧に表示できなかった。
  ;; Eglot側の候補を先に取得して名前だけ記録し、dabbrevだけを除外する。
  ;; HLS同士の同名候補は区別（import元など）を残す。
  (require 'cape)
  (let ((eglot-names (make-hash-table :test #'equal)))
    (cape-wrap-properties
     (lambda ()
       (cape-wrap-super
        (lambda ()
          ;; Eglotの補完tableが持つfilterText等の絞り込みを維持する。
          ;; cape-wrap-passthroughを付けるとT.unpの未一致候補も残るため
          ;; 使用しない。文字列プロパティはそのまま候補へ引き継ぐ。
          (my/eglot-dabbrev--track-candidates
           #'eglot-completion-at-point eglot-names))
        (lambda ()
          (cape-wrap-predicate
           #'my/dabbrev-capf
           (lambda (candidate)
             (not (gethash (substring-no-properties candidate)
                           eglot-names)))))))
     :category 'eglot-capf)))

(defun my/eglot-dabbrev-completion-setup ()
  "Eglot管理中のみ統合CAPFを使い、終了時は元の設定に戻す。"
  ;; eglot-managed-mode-hookはEglotがCAPFを登録/解除した後に呼ばれる。
  ;; 接続し直しても統合CAPFを二重登録しない。
  (if (eglot-managed-p)
      (when (or (memq #'eglot-completion-at-point
                      completion-at-point-functions)
                (memq #'my/eglot-dabbrev-capf
                      completion-at-point-functions))
        (remove-hook 'completion-at-point-functions
                     #'eglot-completion-at-point t)
        (add-hook 'completion-at-point-functions
                  #'my/eglot-dabbrev-capf nil t))
    (remove-hook 'completion-at-point-functions
                 #'my/eglot-dabbrev-capf t)))


(defun my/vertico-sort-project-files (candidates)
  "親ディレクトリ順、次にファイル名順で候補を並べる。"
  (sort candidates
        (lambda (a b)
          (let ((dir-a (or (file-name-directory a) ""))
                (dir-b (or (file-name-directory b) "")))
            (if (string= dir-a dir-b)
                (string-lessp (file-name-nondirectory a)
                              (file-name-nondirectory b))
              (string-lessp dir-a dir-b))))))


(provide 'my-completion)
;;; my-completion.el ends here
