;;; my-flymake-problems-test.el --- Full-text Flymake Problems ERT -*- lexical-binding: t; -*-

;;; Commentary:
;; Flymakeの診断オブジェクトを使用して、一覧の純粋な処理を確認する。
;; 実際のEglot通信や、TRAMP上のファイルオープンは対象外。
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'flymake)
(require 'eglot)
(require 'my-flymake-problems)

(ert-deftest my/flymake-problems-eglot-severity ()
  "Eglotの診断をERROR/WARNING/INFOとして表示する。"
  ;; Eglot 31.1が登録するflymake-categoryを実際に使用する。
  (dolist (case '((eglot-error "ERROR" error)
                  (eglot-warning "WARNING" warning)
                  (eglot-note "INFO" success)
                  (:error "ERROR" error)
                  (:warning "WARNING" warning)
                  (:note "INFO" success)))
    (pcase-let ((`(,type ,label ,face) case))
      (let ((diag (flymake-make-diagnostic
                   "/project/Main.hs" '(1 . 1) nil type "diagnostic")))
        (should (equal (my/flymake-problems--severity diag)
                       (cons label face)))))))

(ert-deftest my/flymake-problems-renders-eglot-error ()
  "HLSのeglot-errorがHINTではなくERRORと全文表示される。"
  (with-temp-buffer
    (let ((diag (flymake-make-diagnostic
                 "/project/Evaluation.hs" '(42 . 1) nil 'eglot-error
                 '("typecheck" "GHC-44432"
                   "The type signature for reciprocalRankAt\nlacks an accompanying binding"))))
      (my/flymake-problems-mode)
      (setq-local my/flymake-problems-project 'mock-project
                  my/flymake-problems-root "/project/")
      (cl-letf (((symbol-function 'flymake--project-diagnostics)
                 (lambda (_) (list diag))))
        (my/flymake-problems-refresh))
      (should (string-match-p
               (regexp-quote "ERROR  42:1  [typecheck]  [GHC-44432]")
               (buffer-string)))
      (should (string-match-p
               (regexp-quote
                "The type signature for reciprocalRankAt\n    lacks an accompanying binding")
               (buffer-string)))
      (should-not (string-match-p "HINT" (buffer-string))))))

(ert-deftest my/flymake-problems-lists-full-multiline-message ()
  "全文とorigin/codeを省略せず、ファイルごとにグループ化する。"
  (with-temp-buffer
    (let* ((early (flymake-make-diagnostic
                   "/project/A.hs" '(3 . 2) nil :error
                   '("HLS" "GHC-123" "first line\nsecond line")))
           (later (flymake-make-diagnostic
                   "/project/A.hs" '(20 . 4) nil :warning
                   '("HLS" nil "warning body")))
           (other (flymake-make-diagnostic
                   "/project/B.hs" '(1 . 1) nil :note
                   '(nil nil "additional note"))))
      (my/flymake-problems-mode)
      (setq-local my/flymake-problems-project 'mock-project
                  my/flymake-problems-root "/project/")
      (cl-letf (((symbol-function 'flymake--project-diagnostics)
                 (lambda (_project) (list later other early))))
        (my/flymake-problems-refresh))
      (let ((output (buffer-string)))
        (should (string-match-p
                 (regexp-quote
                  "A.hs\n  ERROR  3:2  [HLS]  [GHC-123]\n    first line\n    second line\n")
                 output))
        (should (string-match-p
                 (regexp-quote "WARNING  20:4") output))
        (should (string-match-p
                 (regexp-quote "B.hs\n  INFO  1:1") output))
        (should (< (string-match "A.hs" output)
                   (string-match "B.hs" output)))
        (should (= (length my/flymake-problems-positions) 3))))))

(ert-deftest my/flymake-problems-location-for-visited-buffer ()
  "訪問済みファイルの診断はbuffer positionから行・列へ変換する。"
  (with-temp-buffer
    (setq-local buffer-file-name "/project/src/Main.hs")
    (insert "one\n  hello\n")
    (goto-char (point-min))
    (search-forward "hello")
    (backward-char 5)
    (let* ((start (point))
           (diag (flymake-make-diagnostic
                  (current-buffer) start (+ start 5)
                  :error "bad hello"))
           (loc (my/flymake-problems--location diag)))
      (should (equal (cl-subseq loc 0 4)
                     (list "/project/src/Main.hs" 2 3 start)))
      (should (eq (nth 4 loc) (current-buffer))))))

(ert-deftest my/flymake-problems-visit-unvisited-file ()
  "未訪問ファイルの診断位置は1始まりの行・列で復元する。"
  (let ((source (generate-new-buffer " *flymake-problems-source*"))
        (problems (generate-new-buffer " *flymake-problems-view*")))
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert "line1\n  hello\n"))
          (with-current-buffer problems
            (my/flymake-problems-mode)
            ;; special-modeは読み取り専用なので、テスト用の診断を
            ;; 追加する間だけ書き込みを許可する。
            (let ((inhibit-read-only t))
              (insert "  ERROR  2:3\n")
              (add-text-properties
               (point-min) (point-max)
               (list 'my/flymake-problems-location
                     (list "/project/A.hs" 2 3 nil nil))))
            (goto-char (point-min))
            (cl-letf (((symbol-function 'find-file-noselect)
                       (lambda (file)
                         (should (equal file "/project/A.hs"))
                         source))
                      ((symbol-function 'pop-to-buffer)
                       (lambda (buffer &rest _)
                         (set-buffer buffer)))
                      ((symbol-function 'recenter) #'ignore))
              (my/flymake-problems-visit)))
          (with-current-buffer source
            (should (= (line-number-at-pos) 2))
            (should (= (current-column) 2))))
      (kill-buffer source)
      (kill-buffer problems))))

(ert-deftest my/flymake-problems-moves-between-entries ()
  "n/pは全文内の個々の行ではなく、診断単位で移動する。"
  (with-temp-buffer
    (let* ((first (flymake-make-diagnostic
                   "/project/A.hs" '(1 . 1) nil :error
                   '(nil nil "first\nmultiple lines")))
           (second (flymake-make-diagnostic
                    "/project/A.hs" '(2 . 1) nil :warning
                    '(nil nil "second"))))
      (my/flymake-problems-mode)
      (setq-local my/flymake-problems-project 'mock-project
                  my/flymake-problems-root "/project/")
      (cl-letf (((symbol-function 'flymake--project-diagnostics)
                 (lambda (_project) (list first second))))
        (my/flymake-problems-refresh))
      (goto-char (point-min))
      (my/flymake-problems-next)
      (should (= (point) (nth 0 my/flymake-problems-positions)))
      (my/flymake-problems-next)
      (should (= (point) (nth 1 my/flymake-problems-positions)))
      (my/flymake-problems-previous)
      (should (= (point) (nth 0 my/flymake-problems-positions))))))

(ert-deftest my/flymake-problems-no-diagnostics ()
  "診断がなくても一覧を表示し、n/pでエラーにならない。"
  (with-temp-buffer
    (my/flymake-problems-mode)
    (setq-local my/flymake-problems-project 'mock-project
                my/flymake-problems-root "/project/")
    (cl-letf (((symbol-function 'flymake--project-diagnostics)
               (lambda (_project) nil)))
      (my/flymake-problems-refresh))
    (should (string= (buffer-string) "診断はありません。\n"))
    (should-not my/flymake-problems-positions)
    (my/flymake-problems-next)
    (my/flymake-problems-previous)))

(ert-deftest my/flymake-problems-auto-refresh-only-own-project ()
  "別プロジェクトの診断更新時には再描画しない。"
  (let ((problems (get-buffer-create my/flymake-problems-buffer-name))
        (own (generate-new-buffer " *problems-own*"))
        (other (generate-new-buffer " *problems-other*"))
        (calls 0))
    (unwind-protect
        (progn
          (with-current-buffer problems
            (my/flymake-problems-mode)
            (setq-local my/flymake-problems-root "/project/"))
          (with-current-buffer own
            (setq-local buffer-file-name "/project/src/Main.hs"))
          (with-current-buffer other
            (setq-local buffer-file-name "/different/Main.hs"))
          (cl-letf (((symbol-function 'get-buffer-window)
                     (lambda (buffer &optional _)
                       (when (eq buffer problems) (selected-window))))
                    ((symbol-function 'my/flymake-problems-refresh)
                     (lambda () (cl-incf calls))))
            (my/flymake-problems--on-diagnostics-updated own)
            (my/flymake-problems--on-diagnostics-updated other))
          (should (= calls 1)))
      (kill-buffer own)
      (kill-buffer other)
      (kill-buffer problems))))

;;; my-flymake-problems-test.el ends here
