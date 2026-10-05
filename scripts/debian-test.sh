#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${EMACS_DEBIAN_IMAGE:-emacs-cli-debian:31.1}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker が見つかりません。Docker または Colima を起動してください。" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh が見つかりません。GitHub CLI をインストールしてください。" >&2
  exit 1
fi

if ! token=$(gh auth token -h github.com 2>/dev/null); then
  echo "GitHub の認証情報を取得できません。先に gh auth login を実行してください。" >&2
  exit 1
fi

docker build \
  --tag "$image" \
  "$repo_root/docker/debian"

GH_TOKEN="$token" docker run --rm -it \
  -e GH_TOKEN \
  -e LANG=C.UTF-8 \
  -e TERM=xterm-256color \
  -e COLORTERM=truecolor \
  -v "$repo_root:/src/emacs.d:ro" \
  "$image" \
  "$@"
