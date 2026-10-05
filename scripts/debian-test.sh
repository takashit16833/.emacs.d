#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${EMACS_DEBIAN_IMAGE:-emacs-cli-debian:31.1}
container=${EMACS_DEBIAN_CONTAINER:-emacs-cli-debian-test}

usage() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  start    検証用コンテナをバックグラウンドで起動する
  shell    検証用コンテナのシェルを開く
  emacs    検証用コンテナでEmacsを開く
  stop     検証用コンテナを削除する
  rebuild  コンテナを削除してイメージを再ビルドし、起動する

COMMANDを省略した場合は emacs を実行する。
EOF
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker が見つかりません。Docker または Colima を起動してください。" >&2
    exit 1
  fi
}

github_token() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh が見つかりません。GitHub CLI をインストールしてください。" >&2
    exit 1
  fi

  if ! gh auth token -h github.com 2>/dev/null; then
    echo "GitHub の認証情報を取得できません。先に gh auth login を実行してください。" >&2
    exit 1
  fi
}

container_exists() {
  docker container inspect "$container" >/dev/null 2>&1
}

container_running() {
  [ "$(docker container inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" = "true" ]
}

build_image() {
  docker build \
    --tag "$image" \
    "$repo_root/docker/debian"
}

start_container() {
  if container_running; then
    echo "$container は起動済みです。"
    return
  fi

  if container_exists; then
    docker start "$container" >/dev/null
    echo "$container を起動しました。"
    return
  fi

  build_image

  token=$(github_token)

  docker run -d \
    --name "$container" \
    -e GH_TOKEN="$token" \
    -e LANG=C.UTF-8 \
    -e TERM=xterm-256color \
    -e COLORTERM=truecolor \
    -v "$repo_root:/src/emacs.d:ro" \
    "$image" \
    --keepalive \
    >/dev/null

  echo "$container を起動しました。"
}

ensure_container_running() {
  if ! container_running; then
    start_container
  fi
}

run_shell() {
  ensure_container_running

  docker exec -it \
    -e TERM="${TERM:-xterm-256color}" \
    -e COLORTERM="${COLORTERM:-truecolor}" \
    "$container" \
    bash "$@"
}

run_emacs() {
  ensure_container_running

  docker exec -it \
    -e TERM="${TERM:-xterm-256color}" \
    -e COLORTERM="${COLORTERM:-truecolor}" \
    "$container" \
    emacs -nw --debug-init "$@"
}

stop_container() {
  if ! container_exists; then
    echo "$container は存在しません。"
    return
  fi

  docker rm -f "$container" >/dev/null
  echo "$container を削除しました。"
}

rebuild_container() {
  if container_exists; then
    docker rm -f "$container" >/dev/null
  fi

  start_container
}

require_docker

command=${1:-emacs}

case "$command" in
  start)
    start_container
    ;;
  shell|--shell)
    shift
    run_shell "$@"
    ;;
  emacs)
    shift
    run_emacs "$@"
    ;;
  stop)
    stop_container
    ;;
  rebuild)
    rebuild_container
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "不明なコマンドです: $command" >&2
    usage >&2
    exit 2
    ;;
esac
