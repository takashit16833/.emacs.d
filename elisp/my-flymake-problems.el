;;; my-flymake-problems.el --- Full-text project diagnostics -*- lexical-binding: t; -*-

;;; Commentary:
;; 旧my/lsp-problemsの「診断メッセージを複数行のまま全文表示する」
;; ためのUIを、Emacs 31.1標準のFlymakeを使って復元する。
;;
;; Flymake標準のflymake-show-project-diagnosticsは、診断を1行に
;; 整形して表にするため、長いHLS等のエラー全文を一覧で読めない。
;; 取得範囲はFlymake標準のプロジェクト一覧と揃えるため、
;; 非公開のflymake--project-diagnosticsを再利用する。ここには
;; 開いているファイル・foreign diagnostics・未訪問ファイルに
;; 通知された診断が含まれる（ただし全ファイルを検査はしない）。
;;
;; Emacs 31.1に診断更新後の公開hookはないため、標準の一覧も
;; 更新するflymake--update-diagnostics-listingsをadviceする。
;; Flymake内部APIに依存するのはこの取得・更新の2箇所に限定し、
;; Emacs更新時には両関数の仕様を再確認する。
;;; Code:

(require 'cl-lib)
(require 'flymake)
(require 'project)
(require 'subr-x)

(declare-function flymake--project-diagnostics "flymake"
                  (&optional project))
(declare-function flymake--update-diagnostics-listings "flymake"
                  (buffer))

(defconst my/flymake-problems-buffer-name "*Flymake Problems*"
  "全文診断を表示するバッファ名。")

(defvar-local my/flymake-problems-project nil
  "診断を収集する元プロジェクト。")

(defvar-local my/flymake-problems-root nil
  "診断一覧に使うプロジェクトルート。")

(defvar-local my/flymake-problems-positions nil
  "各診断の見出しが始まる位置の昇順リスト。")

(defun my/flymake-problems--location (diagnostic)
  "DIAGNOSTICの場所を(FILE LINE COLUMN POSITION BUFFER)で返す。
LINEとCOLUMNは1始まり。POSITIONは訪問済みバッファ内の位置。"
  (let* ((locus (flymake-diagnostic-buffer diagnostic))
         (beg (flymake-diagnostic-beg diagnostic))
         (file (if (bufferp locus)
                   (and (buffer-live-p locus)
                        (buffer-file-name locus))
                 (and (stringp locus) locus))))
    (when file
      (cond
       ((and (bufferp locus) (buffer-live-p locus) (integerp beg))
        (with-current-buffer locus
          (save-restriction
            (widen)
            (save-excursion
              (goto-char beg)
              (list file (line-number-at-pos)
                    (1+ (- (point) (line-beginning-position)))
                    beg locus)))))
       ((consp beg)
        (list file (car beg) (cdr beg) nil nil))))))

(defun my/flymake-problems--entries (project)
  "PROJECTの診断をファイル名と位置の順に並べたリストにする。"
  (let (entries)
    ;; Flymakeの標準プロジェクト一覧と同じ診断集合を利用する。
    (dolist (diag (flymake--project-diagnostics project))
      (when-let* ((location (my/flymake-problems--location diag)))
        (push (cons location diag) entries)))
    (sort entries
          (lambda (a b)
            (let ((left (car a)) (right (car b)))
              (if (string= (car left) (car right))
                  (if (= (cadr left) (cadr right))
                      (< (caddr left) (caddr right))
                    (< (cadr left) (cadr right)))
                (string-lessp (car left) (car right))))))))

(defun my/flymake-problems--severity (diagnostic)
  "DIAGNOSTICの種類を(ラベル . face)に変換する。"
  ;; Eglotはeglot-error等の独自typeを使うが、Flymakeのカテゴリに
  ;; flymake-error等を登録している。typeの名前ではなくカテゴリで判定する。
  ;; flymake-errorそのものをtypeにするバックエンドにも対応する。
  (let* ((type (flymake-diagnostic-type diagnostic))
         (category (or (get type 'flymake-category) type)))
    (pcase category
      ('flymake-error (cons "ERROR" 'error))
      ('flymake-warning (cons "WARNING" 'warning))
      ('flymake-note (cons "INFO" 'success))
      (_ (cons "UNKNOWN" 'shadow)))))

(defun my/flymake-problems--insert (entry)
  "現在のバッファにENTRYの診断メッセージを全文挿入する。"
  (pcase-let* ((`(,location . ,diag) entry)
               (`(,file ,line ,column ,position ,source) location)
               (`(,label . ,face) (my/flymake-problems--severity diag))
               (origin (flymake-diagnostic-origin diag))
               (code (flymake-diagnostic-code diag))
               (message (or (flymake-diagnostic-message diag) ""))
               (start (point)))
    (push start my/flymake-problems-positions)
    (insert "  " (propertize label 'face face)
            (format "  %d:%d" line column))
    (when origin (insert (format "  [%s]" origin)))
    (when code (insert (format "  [%s]" code)))
    (insert "\n")
    ;; onelinerへ加工せず、改行と各行の内容を保持する。
    (dolist (line-text (split-string message "\n" nil))
      (insert "    " line-text "\n"))
    (insert "\n")
    (add-text-properties
     start (point)
     (list 'my/flymake-problems-location
           (list file line column position source)
           'mouse-face 'highlight
           'help-echo "RET: 診断位置へ移動"))))

(defun my/flymake-problems-refresh ()
  "開いているProblems一覧を、Flymakeの最新診断から描き直す。"
  (interactive)
  (unless my/flymake-problems-project
    (user-error "Problems一覧のプロジェクトが未設定です"))
  (let ((inhibit-read-only t)
        (old-line (line-number-at-pos))
        (entries (my/flymake-problems--entries my/flymake-problems-project))
        last-file)
    (erase-buffer)
    (setq my/flymake-problems-positions nil)
    (if (null entries)
        (insert "診断はありません。\n")
      (dolist (entry entries)
        (let ((file (caar entry)))
          (unless (equal file last-file)
            (setq last-file file)
            (insert
             (propertize
              (condition-case nil
                  (file-relative-name file my/flymake-problems-root)
                (error file))
              'face 'bold)
             "\n"))
          (my/flymake-problems--insert entry))))
    (setq my/flymake-problems-positions
          (nreverse my/flymake-problems-positions))
    ;; 診断が非同期更新されても、読んでいる位置を極力維持する。
    (goto-char (point-min))
    (forward-line (1- old-line))))

(defun my/flymake-problems--location-at-point ()
  "現在位置の診断へのジャンプ情報を返す。"
  (or (get-text-property (point) 'my/flymake-problems-location)
      (when (> (point) (point-min))
        (get-text-property (1- (point))
                           'my/flymake-problems-location))))

(defun my/flymake-problems-visit ()
  "現在位置の診断が指すファイルと場所へ移動する。"
  (interactive)
  (pcase (my/flymake-problems--location-at-point)
    (`(,file ,line ,column ,position ,source)
     (let ((buffer (if (and (bufferp source) (buffer-live-p source))
                       source
                     (find-file-noselect file))))
       (pop-to-buffer buffer)
       (if (and position (eq buffer source))
           (goto-char position)
         (goto-char (point-min))
         (forward-line (1- line))
         (move-to-column (1- column)))
       (recenter)))
    (_ (user-error "この位置に診断はありません"))))

(defun my/flymake-problems-next ()
  "次の診断へ移動する。"
  (interactive)
  (when-let* ((pos (cl-find-if (lambda (n) (> n (point)))
                               my/flymake-problems-positions)))
    (goto-char pos)))

(defun my/flymake-problems-previous ()
  "前の診断へ移動する。"
  (interactive)
  (when-let* ((pos (cl-find-if (lambda (n) (< n (point)))
                               (reverse my/flymake-problems-positions))))
    (goto-char pos)))

(define-derived-mode my/flymake-problems-mode special-mode "Flymake Problems"
  "Flymakeのプロジェクト診断をファイルごとに全文表示する。"
  (setq-local truncate-lines nil)
  (setq-local header-line-format
              " RET: jump   g: refresh   n/p: next/previous   q: close"))

(keymap-set my/flymake-problems-mode-map "RET" #'my/flymake-problems-visit)
(keymap-set my/flymake-problems-mode-map "g" #'my/flymake-problems-refresh)
(keymap-set my/flymake-problems-mode-map "n" #'my/flymake-problems-next)
(keymap-set my/flymake-problems-mode-map "p" #'my/flymake-problems-previous)

(defun my/flymake-problems--on-diagnostics-updated (source)
  "SOURCEの診断更新時、表示中の同一プロジェクトの一覧を更新する。"
  (when-let* ((buffer (get-buffer my/flymake-problems-buffer-name))
              (_ (get-buffer-window buffer t))
              (file (and (buffer-live-p source)
                         (buffer-file-name source))))
    (with-current-buffer buffer
      ;; TRAMPのディレクトリ検査を発生させないよう、パスだけ比較する。
      (when (and my/flymake-problems-root
                 (string-prefix-p my/flymake-problems-root file))
        (my/flymake-problems-refresh)))))

;; Emacs 31.1のFlymakeが一覧を更新する場所で追従する。
(unless (advice-member-p #'my/flymake-problems--on-diagnostics-updated
                         'flymake--update-diagnostics-listings)
  (advice-add 'flymake--update-diagnostics-listings :after
              #'my/flymake-problems--on-diagnostics-updated))

;;;###autoload
(defun my/flymake-problems ()
  "現在のプロジェクトの診断を全文で表示し、再実行時は閉じる。"
  (interactive)
  (if-let* ((window (get-buffer-window
                     my/flymake-problems-buffer-name t)))
      (quit-window nil window)
    (let* ((project (project-current t))
           (root (file-name-as-directory (project-root project)))
           (buffer (get-buffer-create my/flymake-problems-buffer-name)))
      (with-current-buffer buffer
        (unless (derived-mode-p 'my/flymake-problems-mode)
          (my/flymake-problems-mode))
        (setq-local my/flymake-problems-project project
                    my/flymake-problems-root root)
        (my/flymake-problems-refresh))
      (pop-to-buffer buffer))))

(provide 'my-flymake-problems)
;;; my-flymake-problems.el ends here
