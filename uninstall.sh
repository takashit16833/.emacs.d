#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tree_sitter_dir=${EMACS_TREE_SITTER_DIR:-"$repo_root/tree-sitter"}

remove_file() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    rm -f "$1"
    echo "削除しました: $1"
  fi
}

uninstall_haskell_tree_sitter() {
  echo "HaskellのTree-sitter grammarを削除します。"

  for file in \
    "$tree_sitter_dir"/libtree-sitter-haskell.dylib \
    "$tree_sitter_dir"/libtree-sitter-haskell.*.dylib \
    "$tree_sitter_dir"/libtree-sitter-haskell.so \
    "$tree_sitter_dir"/libtree-sitter-haskell.so.* \
    "$tree_sitter_dir"/libtree-sitter-haskell.dll
  do
    remove_file "$file"
  done

  rmdir "$tree_sitter_dir" 2>/dev/null || true
}

main() {
  # install.shで追加した環境構築項目の削除処理はここへ追加していく。
  uninstall_haskell_tree_sitter
}

main "$@"
