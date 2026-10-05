#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tree_sitter_dir=${EMACS_TREE_SITTER_DIR:-"$repo_root/tree-sitter"}
state_file="$tree_sitter_dir/.haskell-grammar"

removed=false

remove_file() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    rm -f "$1"
    echo "削除しました: $1"
    removed=true
  fi
}

uninstall_haskell_tree_sitter() {
  for file in \
    "$tree_sitter_dir"/libtree-sitter-haskell.dylib \
    "$tree_sitter_dir"/libtree-sitter-haskell.*.dylib \
    "$tree_sitter_dir"/libtree-sitter-haskell.so \
    "$tree_sitter_dir"/libtree-sitter-haskell.so.* \
    "$tree_sitter_dir"/libtree-sitter-haskell.dll \
    "$state_file"
  do
    remove_file "$file"
  done

  rmdir "$tree_sitter_dir" 2>/dev/null || true

  if [ "$removed" = false ]; then
    echo "Haskell Tree-sitter grammarはインストールされていません。"
  fi
}

uninstall_haskell_tree_sitter
