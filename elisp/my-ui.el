;;; my-ui.el --- Editing commands -*- lexical-binding: t; -*-

;;; Commentary:
;; 見た目の設定関数をまとめる。

;;; Code:

(require 'seq)
(require 'vc-hooks)


;;; nerd font -------------------------------------------------------

(defvar-local my/file-icon-cache nil
  "現在のバッファのファイルアイコンをキャッシュする。")


(defun my/file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (when buffer-file-name
    (if (equal (car-safe my/file-icon-cache)
               buffer-file-name)
        (cdr my/file-icon-cache)
      ;; ファイル種別ごとの色を使わず、表示先の文字色を継承する。
      (let* ((nerd-icons-color-icons nil)
             (icon (nerd-icons-icon-for-file buffer-file-name)))
        (setq my/file-icon-cache
              (cons buffer-file-name icon))
        icon))))


;;; mood-line -------------------------------------------------------

(defun my/mood-line-segment-file-icon ()
  "現在のファイルに対応するアイコンを返す。"
  (my/file-icon))


;;; tab-line --------------------------------------------------------

(defconst my/tab-line-exclude-condition
  '(or (and "^\\*.*\\*$"
            (not (or "^\\*jq-playground\\*$"
                     (derived-mode . clutch-mode)
                     (derived-mode . haskell-ts-inferior-mode))))
       (derived-mode . magit-mode)
       (derived-mode . dired-mode))
  "tab-lineで非表示にするバッファの条件。
基本的に *...* の特殊バッファを除外するが、Clutch、Haskell REPL、
jq Playgroundは通常のバッファと同様に表示する。")


(defvar-local my/tab-line-git-modified-cache 'unknown
  "Magitから取得した現在のGit差分状態。
`modified' は差分あり、`clean' は差分なし、
`unknown' はVCの状態を参照する。")


(defface my/tab-line-tab-vc-modified
  '((t ()))
  "Git差分があるtab-lineのタブに使うface。"
  :group 'tab-line-faces)


(defun my/tab-line--git-modified-p (buffer)
  "BUFFER のファイルに保存済みのGit差分があるか返す。"
  (with-current-buffer buffer
    (and buffer-file-name
         ;; 未保存の場合は `tab-line-tab-modified' を優先する。
         (not (buffer-modified-p))
         (pcase my/tab-line-git-modified-cache
           ('modified t)
           ('clean nil)
           ;; Magitから状態を取得していない場合は、
           ;; 描画中にGitを実行せずVCが保持している状態だけを見る。
           (_
            (and (eq (vc-file-getprop buffer-file-name 'vc-backend) 'Git)
                 (memq (vc-file-getprop buffer-file-name 'vc-state)
                       '(edited added removed missing conflict))))))))


(defun my/tab-line-update-git-modified-cache (root modified-files)
  "ROOT 以下のbufferへ MODIFIED-FILES のGit差分状態を反映する。"
  (let ((modified-paths (make-hash-table :test #'equal)))
    (dolist (file modified-files)
      (puthash (expand-file-name file root) t modified-paths))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (and buffer-file-name
                   (file-in-directory-p buffer-file-name root))
          (setq my/tab-line-git-modified-cache
                (if (gethash (expand-file-name buffer-file-name)
                             modified-paths)
                    'modified
                  'clean)))))
    (tab-line-force-update t)))


(defun my/tab-line--invalidate-git-modified-cache ()
  "現在のbufferのMagit由来Git差分キャッシュを無効化する。"
  (setq my/tab-line-git-modified-cache 'unknown))


(add-hook 'after-save-hook #'my/tab-line--invalidate-git-modified-cache)
(add-hook 'after-revert-hook #'my/tab-line--invalidate-git-modified-cache)


(defun my/tab-line-tab-face-vc-modified
    (tab _tabs face buffer-p _selected-p)
  "TAB に保存済みのGit差分があれば専用faceを追加する。"
  (let ((buffer (if buffer-p
                    tab
                  (cdr (assq 'buffer tab)))))
    (if (and (buffer-live-p buffer)
             (my/tab-line--git-modified-p buffer))
        `(:inherit (my/tab-line-tab-vc-modified ,face))
      face)))


(defun my/tab-line-cache-key (tabs)
  "TABS のVC状態を含むtab-lineキャッシュキーを返す。"
  (append
   (tab-line-cache-key-default tabs)
   (list
    (mapcar
     (lambda (tab)
       (let ((buffer (if (bufferp tab)
                         tab
                       (cdr (assq 'buffer tab)))))
         (when (buffer-live-p buffer)
           (with-current-buffer buffer
             (when buffer-file-name
               (cons my/tab-line-git-modified-cache
                     (vc-file-getprop buffer-file-name 'vc-state)))))))
     tabs))))


(defun my/tab-bar-tab-name-padding (name _tab _i)
  "タブ名 NAME の左右に余白を加える。"
  (concat "  " name "  "))


(defun my/tab-line-tab-name (buffer &optional _buffers)
  "BUFFER のタブ名を、ファイルアイコン付きで返す。"
  (with-current-buffer buffer
    (if buffer-file-name
        (concat
         (my/file-icon)
         " "
         (buffer-name buffer))
      (buffer-name buffer))))


(defun my/tab-line-tab-name-format (tab tabs)
  "TAB の左右に余白を加え、右側にタブ間の余白を入れて表示する。"
  (let* ((formatted (tab-line-tab-name-format-default tab tabs))
         (properties (and (> (length formatted) 0)
                          (text-properties-at 0 formatted)))
         (left-padding (copy-sequence "  "))
         (right-padding (copy-sequence "  ")))
    (when properties
      (add-text-properties 0 (length left-padding)
                           properties left-padding)
      (add-text-properties 0 (length right-padding)
                           properties right-padding))
    (concat left-padding
            formatted
            right-padding
            " ")))


(defun my/tab-line--stable-buffer-order (old-buffers current-buffers)
  "CURRENT-BUFFERS を OLD-BUFFERS の既存順を維持して並べる。
OLD-BUFFERS にない新しいbufferは末尾へ追加し、
CURRENT-BUFFERS にないbufferは除外する。"
  (let ((existing-buffers
         (seq-filter
          (lambda (buffer)
            (memq buffer current-buffers))
          old-buffers))
        (new-buffers
         (seq-remove
          (lambda (buffer)
            (memq buffer old-buffers))
          current-buffers)))
    (append existing-buffers new-buffers)))


(defun my/tab-line-tabs-bufferlo-buffers ()
  "現在のTabに属するBufferloのbufferを安定した順番で返す。"
  (let* ((window (selected-window))
         (buffers
          (tab-line-tabs-non-excluded
           (seq-filter
            (lambda (buffer)
              ;; " *Minibuf-1*" などの内部bufferは表示しない。
              (not (string-prefix-p " " (buffer-name buffer))))
            (bufferlo-buffer-list))))
         (ordered-buffers
          (my/tab-line--stable-buffer-order
           (window-parameter window 'tab-line-buffers)
           buffers)))
    (set-window-parameter window 'tab-line-buffers ordered-buffers)
    ordered-buffers))


;;; corfu -----------------------------------------------------------

(defun my/corfu-offset-tty-popup (original frame x y width height)
  "TTYのCorfu候補を右へ1文字、下へ1行ずらす。"
  (if (and (not (display-graphic-p))
           (string= (buffer-name) " *corfu*"))
      (funcall original
               frame
               (+ x (default-font-width))
               (+ y (default-line-height))
               width
               height)
    (funcall original frame x y width height)))


(provide 'my-ui)


;;; my-ui.el ends here
