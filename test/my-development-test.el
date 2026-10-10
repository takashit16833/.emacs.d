;;; my-development-test.el --- Tests for my-development -*- lexical-binding: t; -*-

;;; Commentary:
;; `my-development' のテスト。

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'my-development)


;;; HLS completion workaround -----------------------------------------------


;; lsp-modeを読み込めないemacs -Qでも、補完データの変換を検証する。
;; LSPのアクセサだけをplist操作に置き換える（実装本体は変更しない）。
(defmacro my-test/with-mocked-lsp-completion (&rest body)
  "LSPの補完用アクセサをplist版に置き換えてBODYを実行する。"
  (declare (indent 0))
  `(cl-letf (((symbol-function 'lsp:completion-item-data?)
              (lambda (item) (plist-get item :data)))
             ((symbol-function 'lsp-get)
              (lambda (data key) (plist-get data key)))
             ((symbol-function 'lsp-member?)
              (lambda (data key) (plist-member data key)))
             ((symbol-function 'lsp-put)
              (lambda (data key value) (plist-put data key value))))
     ,@body))


(defun my-test/hls-completion-item (value &optional plugin)
  "VALUEを含むPLUGINの補完候補を作る。"
  (list :data
        (list :resolvePlugin (or plugin "ghcide-completions")
              :resolveURI "file:///workspace/app/Main.hs"
              :resolveValue value)))


(ert-deftest my/lsp-completion-fix-haskell-resolve-data-converts-nested-false ()
  "ghcideのresolveValue内のnilはJSON falseに戻すこと。"
  (let* ((value (list :itemNeedsType nil))
         (item (my-test/hls-completion-item value)))
    (my-test/with-mocked-lsp-completion
      (my/lsp-completion-fix-haskell-resolve-data item)
      (should (eq (plist-get value :itemNeedsType) :json-false))
      (should (string-match-p
               "itemNeedsType.*false"
               (json-serialize item :null-object nil :false-object :json-false))))))


(ert-deftest my/lsp-completion-fix-haskell-resolve-data-preserves-true ()
  "真のitemNeedsTypeはそのままにすること。"
  (let* ((value (list :itemNeedsType t))
         (item (my-test/hls-completion-item value)))
    (my-test/with-mocked-lsp-completion
      (my/lsp-completion-fix-haskell-resolve-data item)
      (should (eq (plist-get value :itemNeedsType) t)))))


(ert-deftest my/lsp-completion-fix-haskell-resolve-data-ignores-other-plugin ()
  "ghcide以外のデータを変更しないこと。"
  (let* ((value (list :itemNeedsType nil))
         (item (my-test/hls-completion-item value "other-plugin")))
    (my-test/with-mocked-lsp-completion
      (my/lsp-completion-fix-haskell-resolve-data item)
      (should (plist-member value :itemNeedsType))
      (should-not (plist-get value :itemNeedsType)))))


(ert-deftest my/lsp-completion-fix-haskell-resolve-data-ignores-missing-field ()
  "itemNeedsTypeがなければ新しい項目を作らないこと。"
  (let* ((value (list :itemFile "file:///workspace/app/Main.hs"))
         (item (my-test/hls-completion-item value)))
    (my-test/with-mocked-lsp-completion
      (my/lsp-completion-fix-haskell-resolve-data item)
      (should-not (plist-member value :itemNeedsType)))))


(ert-deftest my/lsp-completion-fix-haskell-resolve-data-ignores-missing-data ()
  "補完候補にdataがなければ何もしないこと。"
  (my-test/with-mocked-lsp-completion
    (should-not
     (my/lsp-completion-fix-haskell-resolve-data
      (list :label "embedText")))))


(ert-deftest my/haskell-lsp-completion-trigger-p-detects-server-trigger ()
  "HLSが宣言した補完トリガーを検出すること。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (insert "Text.")
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t))
              ((symbol-function 'lsp--capability-for-method)
               (lambda (_method) 'completion-options))
              ((symbol-function
                'lsp:completion-options-trigger-characters?)
               (lambda (_options) ["."])))
      (should (equal (my/haskell-lsp-completion-trigger-p) ".")))))


(ert-deftest my/haskell-lsp-completion-trigger-p-ignores-disabled-lsp ()
  "lsp-completion-modeが無効ならtriggerを扱わないこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode nil)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (should-not (my/haskell-lsp-completion-trigger-p)))))


(ert-deftest my/haskell-lsp-completion--call-capf-uses-empty-bounds-after-trigger ()
  "trigger直後ではlsp-modeへ空のsymbol boundsを渡すこと。"
  (with-temp-buffer
    (insert "Text.")
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t))
              ((symbol-function 'bounds-of-thing-at-point)
               (lambda (_thing)
                 '(1 . 2)))
              ((symbol-function 'lsp-completion-at-point)
               (lambda ()
                 (bounds-of-thing-at-point 'symbol))))
      (should
       (equal (my/haskell-lsp-completion--call-capf)
              (cons (point) (point)))))))


(ert-deftest my/haskell-lsp-completion--call-capf-keeps-normal-bounds ()
  "trigger直後でなければ通常のsymbol boundsを変更しないこと。"
  (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
             (lambda () nil))
            ((symbol-function 'lsp-completion-at-point)
             (lambda ()
               (bounds-of-thing-at-point 'symbol)))
            ((symbol-function 'bounds-of-thing-at-point)
             (lambda (_thing)
               '(1 . 2))))
    (should
     (equal (my/haskell-lsp-completion--call-capf)
            '(1 . 2)))))


(ert-deftest my/haskell-lsp-completion-at-point-uses-buster ()
  "Haskell用CAPFはCape busterで入力変更を検出すること。"
  (let (buster-capf)
    (cl-letf (((symbol-function 'cape-wrap-buster)
               (lambda (capf &optional _valid)
                 (setq buster-capf capf)
                 'wrapped-capf)))
      (should
       (eq (my/haskell-lsp-completion-at-point)
           'wrapped-capf))
      (should
       (eq buster-capf
           #'my/haskell-lsp-completion--call-capf)))))


(ert-deftest my/haskell-lsp-completion-reset-on-trigger-closes-session ()
  "trigger入力時は進行中の補完セッションを終了すること。"
  (let ((completion-in-region-mode t)
        completion-arg)
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () t))
              ((symbol-function 'completion-in-region-mode)
               (lambda (arg)
                 (setq completion-arg arg))))
      (my/haskell-lsp-completion-reset-on-trigger))
    (should (= completion-arg -1))))


(ert-deftest my/haskell-lsp-completion-reset-on-trigger-does-nothing-otherwise ()
  "trigger以外の入力では補完セッションを変更しないこと。"
  (let ((completion-in-region-mode t)
        completion-called)
    (cl-letf (((symbol-function 'my/haskell-lsp-completion-trigger-p)
               (lambda () nil))
              ((symbol-function 'completion-in-region-mode)
               (lambda (_arg)
                 (setq completion-called t))))
      (my/haskell-lsp-completion-reset-on-trigger))
    (should-not completion-called)))


(ert-deftest my/haskell-lsp-completion-setup-replaces-only-haskell-capf ()
  "Haskellでは標準LSP CAPFだけを専用CAPFへ差し替えること。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point
                  tags-completion-at-point-function))
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (my/haskell-lsp-completion-setup)
      (should
       (eq (car completion-at-point-functions)
           #'my/haskell-lsp-completion-at-point))
      (should-not
       (memq #'lsp-completion-at-point
             completion-at-point-functions))
      (should
       (memq #'tags-completion-at-point-function
             completion-at-point-functions))
      (should
       (memq #'my/haskell-lsp-completion-reset-on-trigger
             post-self-insert-hook)))))


(ert-deftest my/haskell-lsp-completion-setup-leaves-other-modes-alone ()
  "Haskell以外では標準LSP CAPFを変更しないこと。"
  (with-temp-buffer
    (setq-local lsp-completion-mode t)
    (setq-local completion-at-point-functions
                '(lsp-completion-at-point
                  tags-completion-at-point-function))
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) nil)))
      (my/haskell-lsp-completion-setup)
      (should
       (equal completion-at-point-functions
              '(lsp-completion-at-point
                tags-completion-at-point-function)))
      (should-not
       (memq #'my/haskell-lsp-completion-reset-on-trigger
             post-self-insert-hook)))))


;;; Docker/TRAMP LSP transport ---------------------------------------------


(ert-deftest my/lsp-docker-direct-async-methods-changes-copy-only ()
  "Dockerのdirect async用引数だけコピー上で-iへ変更すること。"
  (let* ((methods
          '(("docker"
             (tramp-login-args
              (("exec") ("-it") ("%h") ("%l"))))
            ("ssh"
             (tramp-login-args
              (("-l") ("%u") ("%h"))))))
         (result (my/lsp-docker-direct-async-methods methods)))
    (should
     (equal
      (cadr
       (assq 'tramp-login-args
             (cdr (assoc "docker" result))))
      '(("exec") ("-i") ("%h") ("%l"))))
    (should
     (equal
      (cadr
       (assq 'tramp-login-args
             (cdr (assoc "docker" methods))))
      '(("exec") ("-it") ("%h") ("%l"))))
    (should
     (equal (assoc "ssh" result)
            (assoc "ssh" methods)))))


(ert-deftest my/lsp-start-workspace-with-docker-direct-async-scopes-settings ()
  "DockerのLSP起動中だけdirect async用設定を適用すること。"
  (let ((methods
         '(("docker"
            (tramp-login-args
             (("exec") ("-it") ("%h") ("%l"))))))
        observed-application
        observed-args)
    ;; 実装側はTRAMPのspecial variableを動的束縛するため、
    ;; lexical-binding下のテストでも同じ条件を明示的に作る。
    (cl-progv '(tramp-methods connection-local-default-application)
        (list methods 'tramp)
      (cl-letf (((symbol-function 'file-remote-p)
                 (lambda (_file &optional identification)
                   (when (eq identification 'method)
                     "docker"))))
        (should
         (eq
          (my/lsp-start-workspace-with-docker-direct-async
           (lambda (_session _client _root &optional _initialization-options)
             (setq observed-application
                   (symbol-value 'connection-local-default-application)
                   observed-args
                   (cadr
                    (assq 'tramp-login-args
                          (cdr
                           (assoc "docker"
                                  (symbol-value 'tramp-methods))))))
             'started)
           nil nil "/docker:test:/workspace" nil)
          'started))))
    (should (eq observed-application 'my-lsp))
    (should
     (equal observed-args
            '(("exec") ("-i") ("%h") ("%l"))))
    (should
     (equal
      (cadr
       (assq 'tramp-login-args
             (cdr (assoc "docker" methods))))
      '(("exec") ("-it") ("%h") ("%l"))))))


(ert-deftest my/lsp-start-workspace-with-docker-direct-async-leaves-local-alone ()
  "Docker以外のLSP起動ではTRAMP設定を変更しないこと。"
  (let ((methods
         '(("docker"
            (tramp-login-args
             (("exec") ("-it") ("%h") ("%l"))))))
        observed-application
        observed-args)
    (cl-progv '(tramp-methods connection-local-default-application)
        (list methods 'tramp)
      (cl-letf (((symbol-function 'file-remote-p)
                 (lambda (&rest _args) nil)))
        (my/lsp-start-workspace-with-docker-direct-async
         (lambda (_session _client _root &optional _initialization-options)
           (setq observed-application
                 (symbol-value 'connection-local-default-application)
                 observed-args
                 (cadr
                  (assq 'tramp-login-args
                        (cdr
                         (assoc "docker"
                                (symbol-value 'tramp-methods)))))))
         nil nil "/tmp/project" nil)))
    (should (eq observed-application 'tramp))
    (should
     (equal observed-args
            '(("exec") ("-it") ("%h") ("%l"))))))



;;; jq Playground ---------------------------------------------------

(ert-deftest my/jq-playground-creates-and-reuses-json-buffer ()
  "Playgroundの再起動でJSONを消さず、通常のキーマップも変更しない。"
  (let ((name "*jq-playground*"))
    (when (get-buffer name)
      (kill-buffer name))
    (unwind-protect
        (save-window-excursion
          (my/jq-playground)
          (should (equal (buffer-name) name))
          (should (derived-mode-p 'js-json-mode))
          (should (equal (buffer-string) "[]\n"))
          (should (eq (key-binding (kbd "C-c C-j"))
                      #'jq-interactively))
          (should-not (eq (current-local-map) js-json-mode-map))
          (erase-buffer)
          (insert "{\"message\":\"hello\"}\n")
          (let ((buffer (current-buffer)))
            (my/jq-playground)
            (should (eq (current-buffer) buffer))
            (should (equal (buffer-string)
                           "{\"message\":\"hello\"}\n"))))
      (when (get-buffer name)
        (kill-buffer name)))))


(ert-deftest my/jq-playground-imports-selected-region ()
  "選択範囲をそのまま取り込み、元のバッファには触れない。"
  (let ((name "*jq-playground*"))
    (when (get-buffer name)
      (kill-buffer name))
    (unwind-protect
        (save-window-excursion
          (with-temp-buffer
            (insert "before not-json after")
            (let ((source (current-buffer))
                  (original (buffer-string)))
              (goto-char (+ (point-min) (length "before ")))
              (set-mark (+ (point) (length "not-json")))
              (setq mark-active t)
              (let ((transient-mark-mode t))
                (should (use-region-p))
                (my/jq-playground))
              (should (equal (buffer-name) name))
              ;; JSONとしての妥当性は検証せず、選択文字列をそのまま使う。
              (should (equal (buffer-string) "not-json"))
              (should (eq (key-binding (kbd "C-c C-j"))
                          #'jq-interactively))
              (with-current-buffer source
                (should (equal (buffer-string) original))))))
      (when (get-buffer name)
        (kill-buffer name)))))


(ert-deftest my/jq-playground-selected-region-replaces-existing-content ()
  "既存のPlaygroundへ取り込むときは内容を置き換える。"
  (let ((name "*jq-playground*"))
    (when (get-buffer name)
      (kill-buffer name))
    (unwind-protect
        (save-window-excursion
          (my/jq-playground)
          (erase-buffer)
          (insert "{\"old\":true}")
          (with-temp-buffer
            (insert "ignore {\"new\":1} ignore")
            (goto-char (+ (point-min) (length "ignore ")))
            (set-mark (+ (point) (length "{\"new\":1}")))
            (setq mark-active t)
            (let ((transient-mark-mode t))
              (should (use-region-p))
              (my/jq-playground))
            (should (equal (buffer-name) name))
            (should (equal (buffer-string) "{\"new\":1}"))))
      (when (get-buffer name)
        (kill-buffer name)))))



;;; TRAMP LSP path workarounds ---------------------------------------------
;;
;; 実際に再現した3言語の問題を、外部Language Serverなしで検証する。
;; TRAMPパスの判定にはEmacs標準のfile-remote-pを使用し、ネットワーク
;; アクセスが必要なファイル検査とNode.jsの実行だけをモックする。
;; 成功ケースに加え、ローカル/相対コマンド/未インストール時の委譲を確認し、
;; workaroundが通常のLSP接続を変えないことを保証する。


(ert-deftest my/lsp-tramp-file-name-adds-connection-only-to-absolute-paths ()
  "サーバーの絶対パスだけをTRAMPパスにし、コマンド名や二重接頭辞は変更しない。"
  (with-temp-buffer
    (let ((default-directory "/docker:debian-test:/workspace/"))
      (should (equal (my/lsp-tramp-file-name "/usr/local/bin/intelephense")
                     "/docker:debian-test:/usr/local/bin/intelephense"))
      (should-not (my/lsp-tramp-file-name "intelephense"))
      (should-not (my/lsp-tramp-file-name
                   "/docker:debian-test:/usr/local/bin/intelephense"))))
  (with-temp-buffer
    (let ((default-directory "/tmp/"))
      (should-not (my/lsp-tramp-file-name "/usr/local/bin/intelephense")))))


(ert-deftest my/lsp-server-present-with-tramp-path-uses-remote-absolute-file ()
  "Lua以外のLSPクライアントが渡す絶対パスはコンテナ側で検査する。"
  (with-temp-buffer
    (let ((default-directory "/docker:debian-test:/workspace/")
          observed-path
          delegated)
      (cl-letf (((symbol-function 'file-executable-p)
                 (lambda (path)
                   (setq observed-path path)
                   t)))
        (should (my/lsp-server-present-with-tramp-path
                 (lambda (_command) (setq delegated t) nil)
                 '("/usr/local/bin/intelephense" "--stdio"))))
      (should (equal observed-path
                     "/docker:debian-test:/usr/local/bin/intelephense"))
      (should-not delegated))))


(ert-deftest my/lsp-server-present-with-tramp-path-rejects-missing-server ()
  "未インストールのサーバーまで存在すると誤判定しない。"
  (with-temp-buffer
    (let ((default-directory "/docker:debian-test:/workspace/"))
      (cl-letf (((symbol-function 'file-executable-p)
                 (lambda (_path) nil)))
        (should-not
         (my/lsp-server-present-with-tramp-path
          (lambda (_command) (ert-fail "unexpected original call"))
          '("/usr/local/bin/missing-server" "--stdio")))))))


(ert-deftest my/lsp-server-present-with-tramp-path-preserves-normal-checks ()
  "ローカル接続とTRAMP上のコマンド名には元の検査関数を使う。"
  (dolist (case '(("/tmp/" ("/usr/local/bin/intelephense" "--stdio"))
                  ("/docker:debian-test:/workspace/" ("intelephense" "--stdio"))))
    (with-temp-buffer
      (let ((default-directory (car case))
            (called nil))
        (cl-letf (((symbol-function 'file-executable-p)
                   (lambda (_path) (ert-fail "unexpected remote check"))))
          (should
           (eq (my/lsp-server-present-with-tramp-path
                (lambda (_command) (setq called t) 'original-result)
                (cadr case))
               'original-result)))
        (should called)))))


(ert-deftest my/lsp-lua-remote-command-setup-is-buffer-local ()
  "Luaの起動コマンドはリモートバッファだけに設定し、ローカルには設定しない。"
  ;; 検証対象をletで動的束縛すると、その束縛がbuffer-local値より
  ;; 優先されてしまう。実際のバッファの値を直接検証する。
  (with-temp-buffer
    (let ((default-directory "/docker:debian-test:/workspace/"))
      (my/lsp-lua-remote-command-setup)
      (should (local-variable-p 'lsp-clients-lua-language-server-command))
      (should (equal lsp-clients-lua-language-server-command
                     '("lua-language-server" "-E")))))
  (with-temp-buffer
    (let ((default-directory "/tmp/"))
      (my/lsp-lua-remote-command-setup)
      (should-not (local-variable-p 'lsp-clients-lua-language-server-command)))))


(ert-deftest my/lsp-typescript-server-path-with-tramp-uses-project-version ()
  "Node.jsが返すコンテナの絶対パスをリモートで検査し、そのまま返す。"
  (with-temp-buffer
    (let ((default-directory "/docker:debian-test:/workspace/typescript-lsp-test/")
          observed-path)
      ;; emacs -Qではlsp-javascriptが未ロードでこのdefcustomも未定義。
      ;; lexical-binding下のletではなく、cl-progvで実際の動的変数を束縛する。
      (cl-progv '(lsp-clients-typescript-prefer-use-project-ts-server) '(t)
        (cl-letf (((symbol-function 'lsp-clients-typescript-require-resolve)
                   (lambda (&optional _dir)
                     "/workspace/typescript-lsp-test/node_modules/typescript/lib"))
                  ((symbol-function 'file-exists-p)
                   (lambda (path) (setq observed-path path) t)))
          (should
           (equal
            (my/lsp-typescript-server-path-with-tramp
             (lambda () (ert-fail "unexpected fallback")))
            "/workspace/typescript-lsp-test/node_modules/typescript/lib"))))
      (should (equal observed-path
                     "/docker:debian-test:/workspace/typescript-lsp-test/node_modules/typescript/lib")))))


(ert-deftest my/lsp-typescript-server-path-with-tramp-preserves-fallback ()
  "TypeScriptがリモートにない場合は元の検出/エラー処理を残す。"
  (with-temp-buffer
    (let ((default-directory "/docker:debian-test:/workspace/")
          (called nil))
      (cl-progv '(lsp-clients-typescript-prefer-use-project-ts-server) '(t)
        (cl-letf (((symbol-function 'lsp-clients-typescript-require-resolve)
                   (lambda (&optional _dir) "/workspace/missing/typescript/lib"))
                  ((symbol-function 'file-exists-p)
                   (lambda (_path) nil)))
          (should
           (eq (my/lsp-typescript-server-path-with-tramp
                (lambda () (setq called t) 'fallback))
               'fallback))))
      (should called))))


(ert-deftest my/lsp-typescript-server-path-with-tramp-leaves-local-and-opt-out ()
  "ローカル接続とプロジェクト優先を無効にした場合はNodeを再実行しない。"
  (dolist (case '(("/tmp/" t)
                  ("/docker:debian-test:/workspace/" nil)))
    (with-temp-buffer
      (let ((default-directory (car case)))
        (cl-progv '(lsp-clients-typescript-prefer-use-project-ts-server)
            (list (cadr case))
          (cl-letf (((symbol-function 'lsp-clients-typescript-require-resolve)
                     (lambda (&optional _dir) (ert-fail "unexpected Node call"))))
            (should
             (eq (my/lsp-typescript-server-path-with-tramp
                  (lambda () 'original-result))
                 'original-result))))))))


;;; my-development-test.el ends here
