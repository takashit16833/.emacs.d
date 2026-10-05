#!/bin/sh
set -eu

EMACS_VERSION=${EMACS_VERSION:-31.1}
PREFIX=${PREFIX:-/usr/local}

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO=sudo
elif [ "$(id -u)" -eq 0 ]; then
  SUDO=
else
  echo "root 権限が必要です。root で実行するか sudo を利用できるようにしてください。" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get が見つかりません。Debian 系 Linux 用のスクリプトです。" >&2
  exit 1
fi

$SUDO apt-get update

gccjit_dev=$(
  apt-cache search '^libgccjit-[0-9][0-9]*-dev$' |
    awk 'NR == 1 { print $1 }'
)

if [ -z "$gccjit_dev" ]; then
  echo "libgccjit の開発パッケージが見つかりません。" >&2
  exit 1
fi

$SUDO apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  gh \
  git \
  "$gccjit_dev" \
  libgmp-dev \
  libgnutls28-dev \
  libncurses-dev \
  libsqlite3-dev \
  libtree-sitter-dev \
  libxml2-dev \
  pkg-config \
  ripgrep \
  texinfo \
  xz-utils \
  zlib1g-dev

current_version=
if [ -x "$PREFIX/bin/emacs" ]; then
  current_version=$("$PREFIX/bin/emacs" --batch --quick --eval '(princ emacs-version)' 2>/dev/null || true)
fi

if [ "$current_version" != "$EMACS_VERSION" ]; then
  work_dir=$(mktemp -d)
  trap 'rm -rf "$work_dir"' EXIT INT TERM

  cd "$work_dir"
  curl -fsSLO "https://ftp.gnu.org/gnu/emacs/emacs-${EMACS_VERSION}.tar.xz"
  tar -xf "emacs-${EMACS_VERSION}.tar.xz"
  cd "emacs-${EMACS_VERSION}"

  ./configure \
    --prefix="$PREFIX" \
    --without-x \
    --with-native-compilation=aot \
    --with-tree-sitter \
    --with-sqlite3 \
    --with-gnutls \
    --with-modules

  make -j"$(nproc)"
  $SUDO make install

  cd /
  rm -rf "$work_dir"
  trap - EXIT INT TERM
fi

if [ -n "${GH_TOKEN:-}" ]; then
  gh auth setup-git >/dev/null
elif gh auth status -h github.com >/dev/null 2>&1; then
  gh auth setup-git >/dev/null
else
  echo
  echo "private GitHub リポジトリ取得のため GitHub にログインします。"
  gh auth login
  gh auth setup-git >/dev/null
fi

echo
echo "GNU Emacs $("$PREFIX/bin/emacs" --batch --quick --eval '(princ emacs-version)') を利用します。"
echo "LANG=C.UTF-8 / TERM=xterm-256color / COLORTERM=truecolor で Emacs を起動します。"
echo

exec env \
  LANG=C.UTF-8 \
  TERM=xterm-256color \
  COLORTERM=truecolor \
  "$PREFIX/bin/emacs" -nw --debug-init
