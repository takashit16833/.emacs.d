#!/bin/sh
set -eu

source_dir=/src/emacs.d
target_dir=/root/.emacs.d

if [ ! -f "$source_dir/init.el" ]; then
  echo "init.el が見つかりません: $source_dir/init.el" >&2
  exit 1
fi

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN がありません。ホスト側で gh auth login を実行してください。" >&2
  exit 1
fi

# package-vc が private リポジトリを取得できるようにする。
# 認証情報そのものはイメージには保存せず、実行時の GH_TOKEN を gh 経由で使う。
gh auth setup-git >/dev/null

# macOS 側で生成されたキャッシュやコンパイル済みファイルは持ち込まず、
# 設定ソースだけを Debian 側の ~/.emacs.d にコピーする。
rm -rf "$target_dir"
mkdir -p "$target_dir"

cd "$source_dir"

tar \
  --exclude='./.git' \
  --exclude='./elpa' \
  --exclude='./eln-cache' \
  --exclude='./tree-sitter' \
  --exclude='./transient' \
  --exclude='./auto-save-list' \
  --exclude='./url' \
  --exclude='./server' \
  --exclude='./history' \
  --exclude='./projects.eld' \
  --exclude='./tramp' \
  --exclude='./recentf' \
  --exclude='./places' \
  --exclude='./bookmarks' \
  --exclude='./package-quickstart.el' \
  --exclude='./package-quickstart.elc' \
  --exclude='*.elc' \
  -cf - . \
  | tar -xf - -C "$target_dir"

cd "$target_dir"

if [ "${1:-}" = "--shell" ]; then
  shift
  exec bash "$@"
fi

exec emacs -nw --debug-init "$@"
