#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tree_sitter_dir=${EMACS_TREE_SITTER_DIR:-"$repo_root/tree-sitter"}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "必要なコマンドが見つかりません: $1" >&2
    exit 1
  fi
}

install_php_tree_sitter() {
  require_command emacs
  require_command git
  require_command cc
  require_command c++

  EMACS_TREE_SITTER_DIR="$tree_sitter_dir" \
    emacs --batch -Q \
    --eval '
      (progn
        (require (quote php-ts-mode))
        (let ((out-dir (getenv "EMACS_TREE_SITTER_DIR"))
              (languages (quote (html css javascript jsdoc php phpdoc))))
          (make-directory out-dir t)
          (setq treesit-extra-load-path
                (cons out-dir treesit-extra-load-path))
          (dolist (lang languages)
            (unless (treesit-language-available-p lang)
              (princ
               (format "%s Tree-sitter grammarをインストールします。\n"
                       lang))
              (treesit-install-language-grammar lang out-dir))
            (unless (treesit-language-available-p lang)
              (princ
               (format "%s Tree-sitter grammarをロードできません。\n"
                       lang))
              (kill-emacs 1)))
          (princ "PHP用Tree-sitter grammarをインストールしました。\n")))'
}

install_php_tree_sitter
