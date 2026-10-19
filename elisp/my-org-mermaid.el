;;; my-org-mermaid.el --- Preview Mermaid diagrams in Org -*- lexical-binding: t; -*-
;;; Commentary:
;; Leave Mermaid rendering to ob-mermaid and terminal image placement to
;; kitty-graphics.el.  This file only manages persistent output filenames,
;; reuse of unchanged PNGs, and the interactive preview command.
;;; Code:

(require 'cl-lib)
(require 'ob)
(require 'org)

(defgroup my/org-mermaid nil
  "Mermaid previews in Org buffers."
  :group 'org)

(defcustom my/org-mermaid-image-directory (expand-file-name "~/images/mermaid/")
  "Directory in which preview PNGs are kept between Emacs sessions."
  :type 'directory
  :group 'my/org-mermaid)

(defun my/org-mermaid--output-file (info)
  "Return a stable, content-dependent PNG filename for Babel INFO.
Changing the source or its header arguments creates a different filename,
so a terminal never has to replace an image stored under the same path."
  (let* ((params (cl-remove-if
                  (lambda (pair) (memq (car pair) '(:file :results :result-params)))
                  (copy-tree (nth 2 info))))
         (key (prin1-to-string
               (list "ob-mermaid-cli-11" (nth 1 info)
                     (sort params
                           (lambda (a b)
                             (string< (symbol-name (car a))
                                      (symbol-name (car b)))))
                     (and (boundp 'ob-mermaid-default-config-file)
                          ob-mermaid-default-config-file))))
         (digest (substring (secure-hash 'sha256 key) 0 24)))
    (expand-file-name (concat "diagram-" digest ".png")
                      my/org-mermaid-image-directory)))

(defun my/org-mermaid--valid-png-p (file)
  "Return non-nil when FILE is an existing, nonempty PNG."
  (and (file-regular-p file)
       (> (file-attribute-size (file-attributes file)) 0)))

;;;###autoload
(defun my/org-mermaid-preview ()
  "Generate or reuse and display the Mermaid source block at point.

Store a content-addressed PNG under `my/org-mermaid-image-directory'.
An existing PNG is reused without running mmdc.  The preview command
overrides :file; normal C-c C-c Babel execution still honors :file.

Image placement is handled by Org and kitty-graphics.el, not here."
  (interactive)
  (let* ((info (org-babel-get-src-block-info))
         (language (car-safe info)))
    (unless (equal language "mermaid")
      (user-error "Mermaidのソースブロック内で実行してください"))
    (let* ((output (my/org-mermaid--output-file info))
           (cached (my/org-mermaid--valid-png-p output))
           (params (list (cons :file output)
                         (cons :results "file graphics replace")
                         ;; The preview manages its own file cache.  If an
                         ;; image is deleted, Babel must regenerate it.
                         (cons :cache "no"))))
      (when (file-remote-p output)
        (user-error "リモートのMermaid画像出力は未対応です"))
      (unless (equal (downcase (or (file-name-extension output) "")) "png")
        (user-error "プレビューの出力形式はPNGを指定してください"))
      (if cached
          ;; Reinsert the standard Babel file result without invoking mmdc.
          (let ((result-info (copy-tree info)))
            (setf (nth 2 result-info)
                  (org-babel-merge-params (nth 2 result-info) params))
            (org-babel-insert-result
             output '("file" "graphics" "replace") result-info))
        (make-directory (file-name-directory output) t)
        (condition-case err
            ;; ob-mermaid handles command execution and Org result insertion.
            (org-babel-execute-src-block nil info params)
          (error
           ;; Never preserve a partial file as a successful cache entry.
           (when (file-exists-p output)
             (delete-file output))
           (signal (car err) (cdr err)))))
      (unless (my/org-mermaid--valid-png-p output)
        (user-error "Mermaid画像を生成できませんでした: %s" output))
      ;; Redisplay through Org's normal inline-image mechanism.  Avoid
      ;; a second image-placement implementation in this extension.
      (when (and (fboundp 'org-display-inline-images)
                 (or (display-graphic-p)
                     (bound-and-true-p kitty-graphics-mode)))
        (org-display-inline-images t t))
      output)))

(provide 'my-org-mermaid)
;;; my-org-mermaid.el ends here
