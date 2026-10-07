;;; my-haskell-indent-test.el --- Indentation tests -*- lexical-binding: t; -*-

;;; Commentary:
;; emacs --batch -Q -L elisp -l test/my-haskell-indent-test.el
;;   -f ert-run-tests-batch-and-exit
;; 実物を使うテストにはFourmoluとHaskellのTree-sitter grammarが必要。
;; haskell-ts-modeもload-pathにあれば、実際のmajor mode上で検証する。

;;; Code:

(require 'ert)
(require 'my-haskell-indent)
(require 'haskell-ts-mode nil t)

(defmacro my-haskell-indent-test--buffer (source &rest body)
  "SOURCEの@POINT@にカーソルを置き、BODYを評価する。"
  (declare (indent 1))
  `(with-temp-buffer
     (if (fboundp 'haskell-ts-mode) (haskell-ts-mode) (prog-mode))
     (setq-local indent-tabs-mode nil)
     (insert ,source)
     (goto-char (point-min))
     (search-forward "@POINT@")
     (replace-match "" t t)
     (my-haskell-indent-mode 1)
     ,@body))

(defmacro my-haskell-indent-test--project (config &rest body)
  "CONFIGを持つ一時プロジェクトでBODYを評価する。"
  (declare (indent 1))
  `(let* ((directory (make-temp-file "haskell-indent-project-" t))
          (default-directory (file-name-as-directory directory)))
     (unwind-protect
         (progn
           (with-temp-file (expand-file-name "fourmolu.yaml" directory)
             (insert ,config))
           ,@body)
       (delete-directory directory t))))

(defun my-haskell-indent-test--require-tools ()
  "実物との接続テストに必要なツールがあることを確認する。"
  (unless (and (executable-find my-haskell-indent-command)
               (treesit-available-p)
               (treesit-language-available-p 'haskell))
    (ert-skip "FourmoluとHaskell grammarが必要")))

;; Fourmoluから答えが取れたことも検証し、代替処理で偶然通ることを防ぐ。
(dolist (case
         '((do "main = do@POINT@" 2)
           (body "foo x =@POINT@" 2)
           (case "foo =\n  case x of@POINT@" 4)
           (case-body "foo =\n  case x of\n    Just y ->@POINT@" 6)
           (nested-do "foo =\n  case x of\n    Just y -> do@POINT@" 6)
           (case-sibling "foo =\n  case x of\n    Just y -> y@POINT@" 4)
           (where "foo = x\n  where@POINT@" 2)
           (where-sibling "foo = x\n where\n  x = 1@POINT@" 2)
           (let "foo =\n  let@POINT@" 4)
           (let-sibling "foo =\n  let x = 1\n      y = 2@POINT@" 6)
           (do-let "main = do\n  let@POINT@" 4)
           (do-let-sibling "main = do\n  let x = 1@POINT@" 6)
           (top-level "foo = 1@POINT@" 0)
           (module "module Main where@POINT@" 0)
           (list "foo = [@POINT@" 4)
           (parens "foo = (@POINT@" 3)
           (record "foo = Person {@POINT@" 6)
           (type "foo ::@POINT@" 2)))
  (let ((name (intern (format "my-haskell-indent-ret-%s" (car case))))
        (source (nth 1 case))
        (column (nth 2 case)))
    (eval
     `(ert-deftest ,name ()
        (my-haskell-indent-test--require-tools)
        (my-haskell-indent-test--project "indentation: 2\n"
          (my-haskell-indent-test--buffer ,source
            (let ((before (buffer-string)))
              (call-interactively (key-binding (kbd "RET")))
              (should (equal (buffer-string)
                             (concat before "\n" (make-string ,column ?\s))))
              (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu))
              (should (= (current-column) ,column))))))
     t)))

(ert-deftest my-haskell-indent-ret-comments ()
  "コメントのインデントを増やさず、前の行も変更しない。"
  (my-haskell-indent-test--require-tools)
  (dolist (source '("-- top@POINT@" "  -- nested@POINT@" "    -- do@POINT@"))
    (my-haskell-indent-test--buffer source
      (let ((before (buffer-string)) (column (current-indentation)))
        (my-haskell-indent-newline)
        (should (equal (buffer-string) (concat before "\n" (make-string column ?\s))))
        (should (eq (plist-get my-haskell-indent-last-result :backend) 'preserve))))))

(ert-deftest my-haskell-indent-tab-and-point ()
  "TABは一度で構造の位置へ移り、繰り返しても循環しない。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "main = do\n    print @POINT@1\n    pure ()\n"
      (indent-for-tab-command)
      (should (equal (buffer-string) "main = do\n  print 1\n  pure ()\n"))
      (should (= (char-after) ?1))
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu))
      (let ((once (buffer-string)))
        (indent-for-tab-command)
        (should (equal (buffer-string) once))))))

(ert-deftest my-haskell-indent-tab-let-and-guards ()
  "横に並ぶ束縛やガードの列もFourmoluに合わせる。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (dolist (case '(("foo =\n    let x = 1\n        @POINT@y = 2\n     in x + y\n" 6)
                    ("foo x\n    | x > 0 = 1\n    @POINT@| otherwise = 0\n" 2)
                    ("foo =\n  case x of\n        @POINT@Nothing -> 0\n" 4)
                    ("foo =\n    let x = 1\n     @POINT@in x\n" 3)))
      (my-haskell-indent-test--buffer (car case)
        (should (= (my-haskell-indent-column) (cadr case)))
        (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu))))))

(ert-deftest my-haskell-indent-does-not-assume-line-numbers ()
  "整形で空行や改行が増減しても目的の語句を対応付ける。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "x=1\ny=2\nmain = do\n    @POINT@print y\n"
      (my-haskell-indent-line)
      (should (equal (buffer-string) "x=1\ny=2\nmain = do\n  print y\n"))
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu)))))

(ert-deftest my-haskell-indent-isolates-other-incomplete-declarations ()
  "他の宣言が壊れていても、完成した対象の宣言を整形できる。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "broken =\nmain = do\n    @POINT@print 1\nnext =\n"
      (my-haskell-indent-line)
      (should (= (current-indentation) 2))
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu)))))

(ert-deftest my-haskell-indent-fourmolu-config ()
  "4スペース、where、letの配置設定を実際のFourmoluに渡す。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 4\nindent-wheres: true\nlet-style: newline\n"
    (dolist (case '(("main = do@POINT@" 4)
                    ("foo = x\n  where@POINT@" 8)
                    ("foo =\n    let@POINT@" 8)))
      (my-haskell-indent-test--buffer (car case)
        (my-haskell-indent-newline)
        (should (= (current-column) (cadr case)))
        (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu))))))

(ert-deftest my-haskell-indent-reloads-config ()
  "同じバッファでも設定ファイル変更後に幅を取得し直す。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "main = do\n@POINT@"
      (should (= (my-haskell-indent-column) 2))
      (let ((file (expand-file-name "fourmolu.yaml" default-directory)))
        (with-temp-file file (insert "indentation: 4\n"))
        (set-file-times file (time-add (current-time) 1)))
      (should (= (my-haskell-indent-column) 4)))))

(ert-deftest my-haskell-indent-keeps-pragma-and-collision ()
  "仮コードにも言語拡張を引き継ぎ、既存の識別名と衝突しない。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "{-# LANGUAGE LambdaCase #-}\nmyHaskellIndentProbe = 1\nf = \\case@POINT@"
      (my-haskell-indent-newline)
      (should (= (current-column) 2))
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu)))))

(ert-deftest my-haskell-indent-region-preserves-body ()
  "範囲は全行を計算してから空白だけを変更する。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "main = do\n    print 1\n    pure ()\n@POINT@"
      (my-haskell-indent-region (point-min) (point-max))
      (should (equal (buffer-string) "main = do\n  print 1\n  pure ()\n")))))

(ert-deftest my-haskell-indent-region-does-not-partially-change-invalid-input ()
  "解析不能な範囲は途中まで変更しない。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--buffer "main = do\n    print 1\nbroken =@POINT@"
    (let ((before (buffer-string)))
      (should-error (my-haskell-indent-region (point-min) (point-max)) :type 'user-error)
      (should (equal before (buffer-string))))))

(ert-deftest my-haskell-indent-refuses-changed-token-sequence ()
  "括弧の追加・語句の並べ替えがあると対応位置を推測しない。"
  (my-haskell-indent-test--require-tools)
  (should-not (my-haskell-indent--mapped-column "x = f a\n" 4 "x = (f a)\n"))
  (should-not (my-haskell-indent--mapped-column "x = a + b\n" 4 "x = b + a\n")))

(ert-deftest my-haskell-indent-missing-executable ()
  "Fourmoluがない場合もRET/TABを使える。"
  (let ((my-haskell-indent-command "/nonexistent/my-indent-formatter"))
    (my-haskell-indent-test--buffer "main = do@POINT@"
      (my-haskell-indent-newline)
      (should (equal (buffer-string) "main = do\n  "))
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fallback))
      (should (eq (plist-get my-haskell-indent-last-result :reason) 'missing-executable)))))

(ert-deftest my-haskell-indent-disabled-mode-restores-state ()
  "元のローカル値とキー割り当てを復元する。二重の有効化にも耐える。"
  (with-temp-buffer
    (prog-mode)
    (setq-local indent-line-function #'ignore)
    (let ((original-region indent-region-function)
          (original-ret (key-binding (kbd "RET"))))
      (my-haskell-indent-mode 1)
      (my-haskell-indent-mode 1)
      (should (eq (key-binding (kbd "RET")) #'my-haskell-indent-newline))
      (should (eq (key-binding (kbd "C-j")) #'my-haskell-indent-newline))
      (my-haskell-indent-mode -1)
      (should (eq indent-line-function #'ignore))
      (should (eq indent-region-function original-region))
      (should (eq (key-binding (kbd "RET")) original-ret))
      (should-not (local-variable-p 'electric-indent-inhibit)))))

(ert-deftest my-haskell-indent-no-mutation-during-calculation ()
  "列の計算だけではバッファ・カーソル・変更フラグを変えない。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "main = do\n@POINT@"
      (set-buffer-modified-p nil)
      (let ((before (buffer-string)) (position (point)))
        (should (= (my-haskell-indent-column) 2))
        (should (equal (buffer-string) before))
        (should (= (point) position))
        (should-not (buffer-modified-p))))))

(ert-deftest my-haskell-indent-timeout-cleans-process ()
  "応答しない外部処理を止め、プロセスと一時バッファを片付ける。"
  (unless (executable-find "python3") (ert-skip "python3が必要"))
  (let* ((script (make-temp-file "haskell slow formatter " nil ".py"))
         (my-haskell-indent-command script)
         (my-haskell-indent-timeout 0.04)
         (before (buffer-list))
         (processes (process-list)))
    (unwind-protect
        (progn
          (with-temp-file script
            (insert "#!/usr/bin/env python3\nimport time\ntime.sleep(1)\n"))
          (set-file-modes script #o700)
          (my-haskell-indent-test--buffer "main = do@POINT@"
            (my-haskell-indent-newline)
            (should (eq (plist-get my-haskell-indent-last-result :reason) 'timeout))
            (should (< (plist-get my-haskell-indent-last-result :seconds) 0.5)))
          (should-not (cl-set-difference (buffer-list) before))
          (should-not (cl-remove-if-not #'process-live-p
                                         (cl-set-difference (process-list) processes))))
      (delete-file script))))

(ert-deftest my-haskell-indent-block-keeps-literal-content ()
  "ブロックを移動しても、複数行の引用内の空白は変更しない。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer
        "{-# LANGUAGE QuasiQuotes #-}\nmain = do\n    @POINT@print [r|hello\n    literal text\n    |]\n    pure ()\n"
      (my-haskell-indent-line)
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu))
      (should (equal (buffer-string)
                     "{-# LANGUAGE QuasiQuotes #-}\nmain = do\n  print [r|hello\n    literal text\n    |]\n  pure ()\n")))))

(ert-deftest my-haskell-indent-region-when-narrowed ()
  "表示範囲を制限していても元バッファ上の位置で対応付ける。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "other = 1\nmain = do\n    @POINT@print 1\n    pure ()\n"
      (let ((begin (line-beginning-position)) (end (point-max)))
        (narrow-to-region begin end)
        (my-haskell-indent-region begin end)
        (should (equal (buffer-string) "  print 1\n  pure ()\n"))
        (should (= (point-min) begin))))))

(ert-deftest my-haskell-indent-keyboard-input ()
  "実際のキー入力経路でも入力と改行を繰り返せる。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (save-window-excursion
      (my-haskell-indent-test--buffer "main = do@POINT@"
        (switch-to-buffer (current-buffer))
        (execute-kbd-macro (kbd "RET"))
        (execute-kbd-macro "print 1")
        (execute-kbd-macro (kbd "RET"))
        (execute-kbd-macro "pure ()")
        (execute-kbd-macro (kbd "TAB"))
        (should (equal (buffer-string) "main = do\n  print 1\n  pure ()"))))))

(ert-deftest my-haskell-indent-recalculates-after-edit ()
  "解析の再利用が、次の操作で変更した内容を隠さない。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "main = do\n@POINT@"
      (should (= (my-haskell-indent-column) 2))
      (erase-buffer)
      (insert "main = 1\n")
      (should (= (my-haskell-indent-column) 0))
      (should (eq (plist-get my-haskell-indent-last-result :backend) 'fourmolu)))))

(ert-deftest my-haskell-indent-line-when-narrowed ()
  "制限された表示範囲でTABを押してもブロック内を正しく移動できる。"
  (my-haskell-indent-test--require-tools)
  (my-haskell-indent-test--project "indentation: 2\n"
    (my-haskell-indent-test--buffer "main = do\n    @POINT@print 1\n    pure ()\n"
      (let ((begin (line-beginning-position)) (end (line-end-position)))
        (narrow-to-region begin end)
        (my-haskell-indent-line)
        (should (buffer-narrowed-p))
        (should (equal (buffer-string) "  print 1"))
        (widen)
        (should (equal (buffer-string) "main = do\n  print 1\n  pure ()\n"))))))

(provide 'my-haskell-indent-test)
;;; my-haskell-indent-test.el ends here
