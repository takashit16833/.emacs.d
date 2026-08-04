;;; retro-hacker-blue-theme.el --- Retro Hacker Blue theme -*- lexical-binding: t; -*-

;;; Commentary:
;; Load the base Retro Hacker Blue theme and extend it with the ANSI palette
;; shared by the Kitty version of the theme.

;;; Code:

(let ((theme-directory
       (file-name-directory (or load-file-name buffer-file-name))))
  (load (expand-file-name "retro-hacker-blue-core.el" theme-directory)
        nil
        t))

(let ((class '((class color) (min-colors 89))))
  ;; Kitty版Retro Hacker Blueと共通のANSIターミナル16色。
  ;; foregroundはANSI文字色、backgroundはANSI背景色として使われる。
  (dolist (entry
           '((black . "#000000")
             (bright-black . "#1A1A1A")
             (red . "#FF5A5A")
             (bright-red . "#FF8080")
             (green . "#4682B4")
             (bright-green . "#6CB8F0")
             (yellow . "#FFD700")
             (bright-yellow . "#FFFF00")
             (blue . "#3B85D8")
             (bright-blue . "#5EAFFF")
             (magenta . "#8A5EC0")
             (bright-magenta . "#B07CFF")
             (cyan . "#00CED1")
             (bright-cyan . "#00FFFF")
             (white . "#E0EEFF")
             (bright-white . "#FFFFFF")))
    (let* ((name (symbol-name (car entry)))
           (color (cdr entry))
           (term-face (intern (format "term-color-%s" name)))
           (vterm-face (intern (format "vterm-color-%s" name))))
      (custom-theme-set-faces
       'retro-hacker-blue
       `(,term-face
         ((,class (:foreground ,color :background ,color))))
       `(,vterm-face
         ((,class (:foreground ,color :background ,color)))))))

  ;; ansi-colorを使うコンパイル出力なども通常8色を共有する。
  (custom-theme-set-variables
   'retro-hacker-blue
   '(ansi-color-names-vector
     ["#000000"
      "#FF5A5A"
      "#4682B4"
      "#FFD700"
      "#3B85D8"
      "#8A5EC0"
      "#00CED1"
      "#E0EEFF"])))

(provide-theme 'retro-hacker-blue)

;;; retro-hacker-blue-theme.el ends here
