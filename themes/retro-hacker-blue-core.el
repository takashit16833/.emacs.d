;;; retro-hacker-blue-theme.el --- Retro Hacker Blue theme -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs port of the VS Code "Retro Hacker Blue" theme.
;; User overrides are prioritized for the cursor, selections, symbol highlights,
;; and search matches.
;;
;; Install to:
;;   ~/.emacs.d/themes/retro-hacker-blue-theme.el

;;; Code:

(deftheme retro-hacker-blue
  "Dark blue retro-hacker theme with cyber-pink accents.")

(let* ((class '((class color) (min-colors 89)))

       ;; Original palette
       (bg "#010111")
       (bg-alt "#010114")
       (bg-deep "#000E2F")
       (panel "#001E4A")
       (section "#0A2D63")
       (focus "#052A59")
       (line-bg "#061536")
       ;; Orgコードブロック用。通常背景よりさらに濃くする。
       (org-block-bg "#07162B")
       (fg "#5EAFFF")
       (fg-dim "#4C9EEB")
       (fg-muted "#316CBD")
       (fg-light "#7CBEFF")
       (fg-pale "#A6CAFF")
       (string "#BFD7FF")
       (white "#FFFFFF")
       (sky "#87CEEB")
       (cyan "#00FFFF")
       (purple "#B07CFF")
       (purple-dark "#8A5EC0")
       (gold "#FFD700")
       (gold-bright "#FFE866")
       (green "#00FF99")
       ;; Original red role replaced with the cyber-pink accent.
       (red "#FF4DE1")
       (red-light "#FF76E8")
       ;; VS Codeの括弧色分けに合わせた3色。
       (delimiter-yellow "#F9D949")
       (delimiter-pink "#CC76D1")
       (delimiter-blue "#4A9DF8")

       ;; VS Code alpha colors blended over #010111
       (selection "#264770")          ; #5EAFFF66
       (inactive-selection "#152745") ; #5EAFFF38
       (selection-match "#0F1F40")    ; #3670BD45
       (word-match "#0F1B34")         ; #5EAFFF26
       (word-match-text "#0C162E")    ; #5EAFFF1F
       (word-match-strong "#27210E")  ; #FFD70026
       (find-current "#56480B")       ; #FFD70055
       (find-other "#013121")         ; #00FF6630
       (find-range "#0C1733")         ; #3670BD33
       (blue-subtle "#0D172F")
       (blue-subtle-2 "#08122E")
       (red-subtle "#310F39")
       (red-subtle-2 "#210A2B")
       (gold-subtle "#211C0F"))

  (custom-theme-set-faces
   'retro-hacker-blue

   ;; Base UI
   `(default ((,class (:background ,bg :foreground ,fg))))
   `(cursor ((,class (:background ,red :foreground ,bg))))
   `(fringe ((,class (:background ,bg-alt :foreground ,fg-muted))))
   `(shadow ((,class (:foreground ,fg-muted))))
   `(success ((,class (:foreground ,cyan :weight bold))))
   `(warning ((,class (:foreground ,gold :weight bold))))
   `(error ((,class (:foreground ,red :weight bold))))
   `(link ((,class (:foreground ,fg-light :underline t))))
   `(link-visited ((,class (:foreground ,purple :underline t))))
   `(button ((,class (:foreground ,fg-light :underline t))))
   `(vertical-border ((,class (:foreground ,fg))))
   `(window-divider ((,class (:foreground "#153A75"))))
   `(window-divider-first-pixel ((,class (:foreground "#153A75"))))
   `(window-divider-last-pixel ((,class (:foreground ,fg))))
   `(highlight ((,class (:background ,blue-subtle :foreground ,white))))
   `(hl-line ((,class (:background ,line-bg :extend t))))
   `(region ((,class (:background ,selection :foreground ,white :extend t))))
   `(secondary-selection
     ((,class (:background ,inactive-selection :foreground ,fg-light :extend t))))
   `(trailing-whitespace ((,class (:background ,red :foreground ,bg))))

   ;; Line numbers and mode line
   `(line-number ((,class (:background ,bg :foreground ,fg-muted))))
   `(line-number-current-line
     ((,class (:background ,line-bg :foreground ,fg :weight bold))))
   `(mode-line
     ((,class (:background "#00184A" :foreground ,fg
                           :box (:line-width 1 :color ,fg)))))
   `(mode-line-active
     ((,class (:background "#00184A" :foreground ,fg
                           :box (:line-width 1 :color ,fg)))))
   `(mode-line-inactive
     ((,class (:background ,bg-deep :foreground ,fg-muted
                           :box (:line-width 1 :color "#153A75")))))
   `(mode-line-buffer-id ((,class (:foreground ,white :weight bold))))
   `(mode-line-emphasis ((,class (:foreground ,gold :weight bold))))
   `(header-line
     ((,class (:background ,panel :foreground ,fg
                           :box nil :overline nil :underline nil))))
   `(header-line-highlight
     ((,class (:background ,focus :foreground ,white
                           :box nil :overline nil :underline nil))))

   ;; LSP UI Peek
   ;; インライン表示のため角丸にはできないが、
   ;; AppleのダークUIに近いフラットな面と青いアクセントで整える。
   `(lsp-ui-peek-peek
     ((,class (:background "#0B1324"
                           :foreground "#D8E8FF"
                           :extend t))))
   `(lsp-ui-peek-list
     ((,class (:background "#101827"
                           :foreground "#C5D5EE"
                           :extend t))))
   `(lsp-ui-peek-header
     ((,class (:background "#15213A"
                           :foreground "#EAF2FF"
                           :weight semi-bold
                           :box nil
                           :overline nil
                           :underline nil
                           :extend t))))
   `(lsp-ui-peek-footer
     ((,class (:inherit lsp-ui-peek-header
                         :box nil
                         :overline nil
                         :underline nil))))
   `(lsp-ui-peek-filename
     ((,class (:foreground "#64D2FF"
                           :weight semi-bold))))
   `(lsp-ui-peek-line-number
     ((,class (:foreground "#6E86AA"))))
   `(lsp-ui-peek-selection
     ((,class (:background "#0A84FF"
                           :foreground "#FFFFFF"
                           :weight semi-bold
                           :box nil
                           :overline nil
                           :underline nil
                           :extend t))))
   `(lsp-ui-peek-highlight
     ((,class (:background "#0A84FF"
                           :foreground "#FFFFFF"
                           :weight semi-bold
                           :box nil
                           :overline nil
                           :underline nil))))

   ;; Tabs
   `(tab-bar
     ((,class (:background ,bg-alt :foreground ,fg-dim
                           :box (:line-width 1 :color ,fg)))))
   `(tab-bar-tab
     ((,class (:background ,bg :foreground ,fg :weight bold
                           :box (:line-width 1 :color ,fg)))))
   `(tab-bar-tab-inactive
     ((,class (:background ,bg-deep :foreground ,fg-muted))))
   `(tab-line ((,class (:background ,bg-alt :foreground ,fg-dim))))
   `(tab-line-tab-current
     ((,class (:background ,bg :foreground ,fg :weight bold
                           :box (:line-width 1 :color ,fg)))))
   `(tab-line-tab-inactive
     ((,class (:background ,bg-deep :foreground ,fg-muted))))

   ;; Minibuffer and Vertico
   `(minibuffer-prompt ((,class (:foreground ,fg :weight bold))))
   `(completions-annotations ((,class (:foreground ,fg-muted :slant italic))))
   `(completions-common-part ((,class (:foreground ,fg :weight bold))))
   `(completions-first-difference ((,class (:foreground ,gold :weight bold))))
   `(completions-highlight
     ((,class (:background ,focus :foreground ,white :weight bold))))
   `(vertico-current
     ((,class (:background ,focus :foreground ,white :extend t))))
   `(vertico-group-title ((,class (:foreground ,fg-light :weight bold))))
   `(vertico-group-separator
     ((,class (:foreground ,fg-muted :strike-through t))))

   ;; Search and symbol-at-point highlights
   `(isearch
     ((,class (:background ,find-current :foreground ,gold-bright :weight bold
                           :box (:line-width -1 :color ,gold-bright)))))
   `(query-replace ((,class (:inherit isearch))))
   `(lazy-highlight
     ((,class (:background ,find-other :foreground ,white
                           :box (:line-width -1 :color ,green)))))
   `(isearch-fail
     ((,class (:background ,red-subtle :foreground ,red :weight bold
                           :box (:line-width -1 :color ,red)))))
   `(isearch-group-1
     ((,class (:background ,find-range :foreground ,fg-light
                           :box (:line-width -1 :color ,fg-light)))))
   `(match
     ((,class (:background ,selection-match :foreground ,white
                           :box (:line-width -1 :color ,fg-light)))))
   `(highlight-symbol-face
     ((,class (:background ,word-match :foreground ,white
                           :box (:line-width -1 :color ,fg-light)))))
   `(symbol-overlay-default-face
     ((,class (:background ,word-match :foreground ,white
                           :box (:line-width -1 :color ,fg-light)))))
   `(eglot-highlight-symbol-face
     ((,class (:background ,word-match-text :foreground ,white
                           :box (:line-width -1 :color ,fg-light)))))
   `(lsp-face-highlight-textual
     ((,class (:background ,word-match-text :foreground ,white
                           :box (:line-width -1 :color ,fg-light)))))
   `(lsp-face-highlight-read
     ((,class (:background ,word-match :foreground ,white
                           :box (:line-width -1 :color ,fg-light)))))
   `(lsp-face-highlight-write
     ((,class (:background ,word-match-strong :foreground ,gold-bright
                           :box (:line-width -1 :color ,gold)))))

   ;; Parentheses
   `(show-paren-match
     ((,class (:background ,word-match :foreground ,white :weight bold
                           :box (:line-width -1 :color ,fg-light)))))
   `(show-paren-mismatch
     ((,class (:background ,red-subtle :foreground ,red :weight bold
                           :box (:line-width -1 :color ,red)))))

   ;; Rainbow Delimiters
   `(rainbow-delimiters-depth-1-face
     ((,class (:foreground ,delimiter-yellow))))
   `(rainbow-delimiters-depth-2-face
     ((,class (:foreground ,delimiter-pink))))
   `(rainbow-delimiters-depth-3-face
     ((,class (:foreground ,delimiter-blue))))
   `(rainbow-delimiters-depth-4-face
     ((,class (:foreground ,delimiter-yellow))))
   `(rainbow-delimiters-depth-5-face
     ((,class (:foreground ,delimiter-pink))))
   `(rainbow-delimiters-depth-6-face
     ((,class (:foreground ,delimiter-blue))))
   `(rainbow-delimiters-depth-7-face
     ((,class (:foreground ,delimiter-yellow))))
   `(rainbow-delimiters-depth-8-face
     ((,class (:foreground ,delimiter-pink))))
   `(rainbow-delimiters-depth-9-face
     ((,class (:foreground ,delimiter-blue))))
   `(rainbow-delimiters-unmatched-face
     ((,class (:foreground ,red :weight bold))))
   `(rainbow-delimiters-mismatched-face
     ((,class (:foreground ,red :weight bold))))

   ;; Syntax highlighting
   `(font-lock-comment-face
     ((,class (:foreground "#7F8DD4" :slant italic))))
   `(font-lock-comment-delimiter-face
     ((,class (:foreground "#7F8DD4" :slant italic))))
   `(font-lock-doc-face
     ((,class (:foreground "#7083C9" :slant italic))))
   `(font-lock-string-face ((,class (:foreground ,string))))
   `(font-lock-keyword-face
     ((,class (:foreground ,fg-pale :weight bold))))
   `(font-lock-builtin-face
     ((,class (:foreground ,fg :weight bold))))
   `(font-lock-function-name-face
     ((,class (:foreground ,sky :weight bold))))
   `(font-lock-function-call-face ((,class (:foreground ,sky))))
   `(font-lock-type-face
     ((,class (:foreground ,fg-pale :weight bold))))
   `(haskell-constructor-face
     ((,class (:foreground ,gold :weight bold))))
   `(font-lock-variable-name-face ((,class (:foreground ,fg-light))))
   `(font-lock-variable-use-face ((,class (:foreground ,fg-pale))))
   `(font-lock-property-name-face ((,class (:foreground ,fg-pale))))
   `(font-lock-property-use-face ((,class (:foreground ,fg-light))))
   `(font-lock-constant-face ((,class (:foreground ,gold))))
   `(font-lock-number-face ((,class (:foreground ,gold))))
   `(font-lock-preprocessor-face
     ((,class (:foreground ,fg :weight bold))))
   `(font-lock-warning-face
     ((,class (:foreground ,red :weight bold :underline t))))
   `(font-lock-bracket-face ((,class (:foreground "#6694CA"))))
   `(font-lock-delimiter-face ((,class (:foreground "#83B9FF"))))
   `(font-lock-punctuation-face ((,class (:foreground "#6694CA"))))
   `(font-lock-operator-face ((,class (:foreground "#83B9FF"))))

   ;; Org
   `(org-document-title
     ((,class (:foreground ,fg :weight bold :height 1.35))))
   `(org-level-1 ((,class (:foreground ,fg :weight bold :height 1.22))))
   `(org-level-2 ((,class (:foreground ,sky :weight bold :height 1.15))))
   `(org-level-3 ((,class (:foreground ,purple :weight bold :height 1.10))))
   `(org-level-4 ((,class (:foreground ,fg-pale :weight bold))))
   `(org-level-5 ((,class (:foreground ,gold :weight bold))))
   `(org-level-6 ((,class (:foreground ,cyan :weight bold))))
   `(org-level-7 ((,class (:foreground ,purple-dark :weight bold))))
   `(org-level-8 ((,class (:foreground ,fg-dim :weight bold))))
   `(org-block
     ((,class (:background ,org-block-bg :foreground ,string :extend t))))
   `(org-block-begin-line
     ((,class (:background ,org-block-bg :foreground ,fg-muted
                           :slant italic :extend t))))
   `(org-block-end-line
     ((,class (:background ,org-block-bg :foreground ,fg-muted
                           :slant italic :extend t))))
   `(org-code
     ((,class (:foreground ,cyan :background ,blue-subtle))))
   `(org-verbatim
     ((,class (:foreground ,gold :background ,gold-subtle))))
   `(org-table ((,class (:foreground ,fg-light))))
   `(org-link ((,class (:foreground ,fg-light :underline t))))
   `(org-tag ((,class (:foreground ,purple :weight bold))))
   `(org-formula ((,class (:foreground ,red))))
   `(org-todo ((,class (:foreground ,red :weight bold))))
   `(org-done ((,class (:foreground ,cyan :weight bold))))
   `(org-date ((,class (:foreground ,sky :underline t))))
   `(org-special-keyword ((,class (:foreground ,fg-muted))))
   `(org-meta-line ((,class (:foreground ,fg-muted :slant italic))))
   `(org-ellipsis ((,class (:foreground ,fg-muted :underline nil))))

   ;; Markdown
   `(markdown-header-face-1
     ((,class (:foreground ,fg :weight bold :height 1.22))))
   `(markdown-header-face-2
     ((,class (:foreground ,sky :weight bold :height 1.15))))
   `(markdown-header-face-3
     ((,class (:foreground ,purple :weight bold :height 1.10))))
   `(markdown-bold-face ((,class (:foreground ,fg :weight bold))))
   `(markdown-italic-face ((,class (:foreground ,fg-light :slant italic))))
   `(markdown-code-face
     ((,class (:foreground ,cyan :background ,blue-subtle))))
   `(markdown-inline-code-face
     ((,class (:foreground ,cyan :background ,blue-subtle))))
   `(markdown-link-face ((,class (:foreground ,fg-light :underline t))))
   `(markdown-markup-face ((,class (:foreground ,fg-muted))))

   ;; Dired
   `(dired-directory ((,class (:foreground ,fg :weight bold))))
   `(dired-symlink ((,class (:foreground ,cyan))))
   `(dired-header ((,class (:foreground ,sky :weight bold))))
   `(dired-marked
     ((,class (:foreground ,gold :background ,gold-subtle :weight bold))))
   `(dired-flagged
     ((,class (:foreground ,red :background ,red-subtle-2 :weight bold))))

   ;; Diff and Magit
   `(diff-header
     ((,class (:background ,panel :foreground ,fg-muted :extend t))))
   `(diff-file-header
     ((,class (:background ,section :foreground ,fg :weight bold :extend t))))
   `(diff-hunk-header
     ((,class (:background ,focus :foreground ,fg-light :extend t))))
   `(diff-added
     ((,class (:background ,blue-subtle-2 :foreground "#6CB8F0" :extend t))))
   `(diff-removed
     ((,class (:background ,red-subtle :foreground ,red-light :extend t))))
   `(diff-changed
     ((,class (:background ,gold-subtle :foreground ,gold :extend t))))
   `(diff-refine-added
     ((,class (:background ,selection :foreground ,white :weight bold))))
   `(diff-refine-removed
     ((,class (:background ,red-subtle-2 :foreground ,red-light :weight bold))))
   `(magit-section-heading ((,class (:foreground ,fg :weight bold))))
   `(magit-section-highlight
     ((,class (:background ,blue-subtle :extend t))))
   `(magit-branch-local ((,class (:foreground ,sky :weight bold))))
   `(magit-branch-remote ((,class (:foreground ,purple :weight bold))))
   `(magit-hash ((,class (:foreground ,fg-muted))))
   `(magit-tag ((,class (:foreground ,gold :weight bold))))
   `(magit-diff-added
     ((,class (:background ,blue-subtle-2 :foreground "#6CB8F0" :extend t))))
   `(magit-diff-removed
     ((,class (:background ,red-subtle-2 :foreground ,red-light :extend t))))

   ;; Diff HL
   `(diff-hl-insert
     ((,class (:inherit fringe :foreground ,fg :background unspecified
                         :weight normal :box nil))))
   `(diff-hl-change
     ((,class (:inherit fringe :foreground ,gold :background unspecified
                         :weight normal :box nil))))
   `(diff-hl-delete
     ((,class (:inherit fringe :foreground ,red :background unspecified
                         :weight normal :box nil))))
   `(diff-hl-dired-insert
     ((,class (:inherit fringe :foreground ,fg :background unspecified
                         :weight normal :box nil))))
   `(diff-hl-dired-change
     ((,class (:inherit fringe :foreground ,gold :background unspecified
                         :weight normal :box nil))))
   `(diff-hl-dired-delete
     ((,class (:inherit fringe :foreground ,red :background unspecified
                         :weight normal :box nil))))

   ;; Diagnostics
   `(flymake-error
     ((,class (:underline (:style wave :color ,red)))))
   `(flymake-warning
     ((,class (:underline (:style wave :color ,gold)))))
   `(flymake-note
     ((,class (:underline (:style wave :color ,fg-light)))))
   `(flycheck-error
     ((,class (:underline (:style wave :color ,red)))))
   `(flycheck-warning
     ((,class (:underline (:style wave :color ,gold)))))
   `(flycheck-info
     ((,class (:underline (:style wave :color ,fg-light)))))
   `(compilation-error ((,class (:foreground ,red :weight bold))))
   `(compilation-warning ((,class (:foreground ,gold :weight bold))))
   `(compilation-info ((,class (:foreground ,fg-light))))

   ;; Help and shell
   `(help-key-binding
     ((,class (:background ,blue-subtle :foreground ,gold
                           :box (:line-width -1 :color ,fg-muted)))))
   `(eshell-prompt ((,class (:foreground ,fg :weight bold))))
   `(eshell-ls-directory ((,class (:foreground ,fg :weight bold))))
   `(eshell-ls-symlink ((,class (:foreground ,cyan))))
   `(eshell-ls-executable ((,class (:foreground ,gold :weight bold))))
   `(eshell-ls-missing ((,class (:foreground ,red :weight bold)))))

  (custom-theme-set-variables
   'retro-hacker-blue
   `(ansi-color-names-vector
     ["#000000" ,red "#4682B4" ,gold "#3B85D8"
      ,purple-dark "#00CED1" "#E0EEFF"])))

;; haskell-ts-modeはfield_nameを独立したfaceへ割り当てないため、
;; Retro Hacker Blueのレコードキーとフィールド参照を淡い青で強調する。
(defun retro-hacker-blue--haskell-ts-highlight-record-fields ()
  "Haskellのレコードフィールド名をTree-sitterで強調する。"
  (unless (memq 'retro-hacker-record-field
                (apply #'append treesit-font-lock-feature-list))
    (setq-local
     treesit-font-lock-settings
     (append
      treesit-font-lock-settings
      (treesit-font-lock-rules
       :language 'haskell
       :feature 'retro-hacker-record-field
       :override t
       '((field_name) @font-lock-property-name-face))))
    (let ((features (copy-tree treesit-font-lock-feature-list)))
      (setf (nth 3 features)
            (append (nth 3 features)
                    '(retro-hacker-record-field)))
      (setq-local treesit-font-lock-feature-list features))
    (treesit-font-lock-recompute-features)
    (font-lock-flush)))

(with-eval-after-load 'haskell-ts-mode
  (add-hook
   'haskell-ts-mode-hook
   #'retro-hacker-blue--haskell-ts-highlight-record-fields))

;;;###autoload
(when (and load-file-name
           (boundp 'custom-theme-load-path))
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory
                (file-name-directory load-file-name))))

(provide-theme 'retro-hacker-blue)

;;; retro-hacker-blue-theme.el ends here
