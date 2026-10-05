#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tree_sitter_dir=${EMACS_TREE_SITTER_DIR:-"$repo_root/tree-sitter"}

haskell_tree_sitter_repo=https://github.com/dschrempf/tree-sitter-haskell.git
haskell_tree_sitter_rev=f3fd0ad1e47aa0ff590479afb1f3e8275e4381cb
haskell_tree_sitter_abi=15
state_file="$tree_sitter_dir/.haskell-grammar"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "必要なコマンドが見つかりません: $1" >&2
    exit 1
  fi
}

library_name() {
  case "$(uname -s)" in
    Darwin)
      printf '%s\n' "libtree-sitter-haskell.dylib"
      ;;
    Linux)
      printf '%s\n' "libtree-sitter-haskell.so"
      ;;
    *)
      echo "未対応のOSです: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

check_tree_sitter_abi() {
  EMACS_TREE_SITTER_ABI="$haskell_tree_sitter_abi" \
    emacs --batch -Q \
    --eval '
      (progn
        (require (quote treesit))
        (unless (treesit-available-p)
          (princ "EmacsがTree-sitterに対応していません。\n")
          (kill-emacs 1))
        (let* ((required
                (string-to-number
                 (or (getenv "EMACS_TREE_SITTER_ABI") "")))
               (minimum (treesit-library-abi-version t))
               (maximum (treesit-library-abi-version)))
          (princ
           (format "Tree-sitter ABI: %d-%d (required: %d)\n"
                   minimum maximum required))
          (unless (<= minimum required maximum)
            (princ "必要なTree-sitter ABIに対応していません。\n")
            (kill-emacs 1))))'
}

grammar_available_p() {
  EMACS_TREE_SITTER_DIR="$tree_sitter_dir" \
    emacs --batch -Q \
    --eval '
      (progn
        (require (quote treesit))
        (setq treesit-extra-load-path
              (list (getenv "EMACS_TREE_SITTER_DIR")))
        (unless (treesit-language-available-p (quote haskell))
          (kill-emacs 1)))' \
    >/dev/null 2>&1
}

state_matches_p() {
  [ -f "$state_file" ] || return 1

  expected=$(printf 'revision=%s\nabi=%s' \
    "$haskell_tree_sitter_rev" \
    "$haskell_tree_sitter_abi")
  actual=$(cat "$state_file")

  [ "$actual" = "$expected" ]
}

already_installed_p() {
  library="$tree_sitter_dir/$(library_name)"
  [ -f "$library" ] && state_matches_p && grammar_available_p
}

install_haskell_tree_sitter() {
  require_command git
  require_command cmake
  require_command tree-sitter
  require_command cc
  require_command emacs

  check_tree_sitter_abi

  if already_installed_p; then
    echo "Haskell Tree-sitter grammarはインストール済みです。"
    return
  fi

  echo "Haskell Tree-sitter grammarをインストールします。"

  tmpdir=$(mktemp -d)
  src_dir="$tmpdir/tree-sitter-haskell"
  build_dir="$tmpdir/build"
  library=$(library_name)

  trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

  git clone --quiet "$haskell_tree_sitter_repo" "$src_dir"
  git -C "$src_dir" checkout --quiet "$haskell_tree_sitter_rev"

  cmake \
    -S "$src_dir" \
    -B "$build_dir" \
    -DBUILD_SHARED_LIBS=ON \
    -DTREE_SITTER_ABI_VERSION="$haskell_tree_sitter_abi" \
    -DCMAKE_BUILD_TYPE=Release

  cmake --build "$build_dir"

  if [ ! -e "$build_dir/$library" ]; then
    echo "ビルドした共有ライブラリが見つかりません: $build_dir/$library" >&2
    exit 1
  fi

  mkdir -p "$tree_sitter_dir"
  rm -f "$state_file"
  install -m 0755 \
    "$build_dir/$library" \
    "$tree_sitter_dir/$library"

  if ! grammar_available_p; then
    echo "Haskell Tree-sitter grammarをロードできません。" >&2
    exit 1
  fi

  printf 'revision=%s\nabi=%s\n' \
    "$haskell_tree_sitter_rev" \
    "$haskell_tree_sitter_abi" \
    > "$state_file"

  rm -rf "$tmpdir"
  trap - EXIT HUP INT TERM

  echo "Haskell Tree-sitter grammarをインストールしました。"
}

install_haskell_tree_sitter
