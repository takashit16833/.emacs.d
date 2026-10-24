;;; my-tab-context.el --- Commands using the current Tab context -*- lexical-binding: t; -*-

;;; Commentary:
;; Tab Router が現在のTabに保存している基準ディレクトリを使って、
;; Project・Magit・Diredなどのコマンドを実行する。

;;; Code:

(require 'project)

(declare-function tab-router-current-directory "tab-router")
(declare-function magit-status "magit-status")
(declare-function dirvish "dirvish" (&optional path))
(declare-function dirvish-subtree-expand-to "dirvish-subtree" (target))
(declare-function dirvish--redisplay "dirvish" ())
(declare-function dired-get-filename "dired" (&optional localp no-error-if-not-filep))


(defun my/tab-context-directory ()
  "現在の操作で基準にするディレクトリを返す。

`project-switch-project' などによって
`project-current-directory-override' が設定されている場合は、
そのディレクトリを優先する。

それ以外では、現在のTabにTab Routerが保存している
基準ディレクトリを返す。"
  (or project-current-directory-override
      (when (fboundp 'tab-router-current-directory)
        (tab-router-current-directory))))


(defun my/project-find-file (&optional include-all)
  "現在のTabを基準に `project-find-file' を実行する。

Tabに基準ディレクトリが設定されていない場合は、
通常の `project-find-file' と同じように現在のbufferから
Projectを判定する。"
  (interactive "P")
  (let ((project-current-directory-override
         (my/tab-context-directory)))
    (project-find-file include-all)))


(defun my/magit-status ()
  "現在のTabを基準に `magit-status' を開く。

Tabに基準ディレクトリが設定されていない場合は、
通常の `magit-status' を実行する。"
  (interactive)
  (if-let* ((directory (my/tab-context-directory)))
      (magit-status directory)
    (ca(defun my/tab-context--dirvish-visible-file (file)
  "現在のDirvishツリーに表示されているFILEの位置を返す。"
  (save-excursion
    (goto-char (point-min))
    (catch 'found
      (while (not (eobp))
        (when (equal (dired-get-filename nil t) file)
          (throw 'found (point)))
        (forward-line 1)))))


(defun my/tab-context--dirvish-goto-file (file)
  "Dirvishの既存ツリーを優先してFILEに移動する。
FILEが非表示なら親ディレクトリを展開して移動する。"
  (if-let* ((position (my/tab-context--dirvish-visible-file file)))
      (progn (goto-char position) t)
    (goto-char (point-min))
    ;; 展開関数の戻り値ではなく、最終的なカーソル位置で判定する。
    (dirvish-subtree-expand-to file)
    (equal (dired-get-filename nil t) file)))


(defun my/project-dirvish ()
  "現在のTabを基準にDirvishを開き、編集中のファイルに追従する。"
  (interactive)
  (let ((file (and buffer-file-name
                   (expand-file-name buffer-file-name)))
        (root (expand-file-name
               (or (my/tab-context-directory) default-directory))))
    (dirvish root)
    (when file
      (cond
       ((not (derived-mode-p 'dired-mode))
        (message "Dirvish: ファイル一覧へ切り替わっていません"))
       ((not (file-in-directory-p
              file (expand-file-name default-directory)))
        (message "Dirvish: 対象は表示ルートの外です: %s" file))
       (t
        (require 'dirvish-subtree)
        (if (my/tab-context--dirvish-goto-file file)
            (progn
              (dirvish--redisplay)
              ;; 再利用した一覧でも選択行を画面内へ移動する。
              (when (eq (current-buffer) (window-buffer))
                (recenter)))
          (message "Dirvish: ファイルへの追従に失敗しました: %s"
                   file)))))))


(provide 'my-tab-context)

;;; my-tab-context.el ends here
